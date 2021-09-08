# -*- coding: utf-8 -*-
# 通知管理プラグイン

require 'mui/gtk_tree_view_pretty_scroll'

require_relative 'model_selector'

require "set"

# アクティビティタブに保持する通知の数
UserConfig[:activity_max] ||= 1000

Plugin.create(:activity_gtk) do

  class ActivityView < ::Gtk::CompatListView
    include ::Gtk::TreeViewPrettyScroll

    ICON = 0
    KIND = 1
    TITLE = 2
    DATE = 3
    MODEL = 4
    URI = 5

    def initialize(plugin)
      type_strict plugin => Plugin
      @plugin = plugin
      super()
    end

    def column_schemer
      [{:kind => :pixbuf, :type => GdkPixbuf::Pixbuf, :label => 'icon'}, # ICON
       {:kind => :text, :type => String, :label => _('種類')},      # KIND
       {:kind => :text, :type => String, :label => _('説明')},      # TITLE
       {:kind => :text, :type => String, :label => _('時刻')},      # DATE
       {type: Plugin::Activity::Activity},                         # Activity Model
       {type: String}                                              # URI
      ].freeze
    end

    def method_missing(*args, &block)
      @plugin.__send__(*args, &block)
    end
  end

  @contains_uris = Set.new

  # そのイベントをミュートするかどうかを返す(trueなら表示しない)
  def mute?(params)
    mute_kind = UserConfig[:activity_mute_kind]
    if mute_kind.is_a? Array
      return true if mute_kind.map(&:to_s).include? params[:kind].to_s end
    mute_kind_related = UserConfig[:activity_mute_kind_related]
    if mute_kind_related
      return true if mute_kind_related.map(&:to_s).include?(params[:kind].to_s) and !params[:related] end
    false end

  # アクティビティの古い通知を一定時間後に消す
  def reset_activity(model)
    Delayer.new(delay: 60) do
      if not model.destroyed?
        iters = model.to_enum(:each).to_a
        remove_count = iters.size - UserConfig[:activity_max]
        if remove_count > 0
          iters[-remove_count, remove_count].each do |_m,_p,iter|
            @contains_uris.delete(iter[ActivityView::URI])
            model.remove(iter)
          end
        end
        reset_activity(model)
      end
    end
  end

  def gen_icon_modifier(tree_model, activity)
    ->loaded_icon {
      uri_string = activity.uri.to_s.freeze
      if !tree_model.destroyed? and @contains_uris.include?(uri_string)
        selected_iter = tree_model.to_enum(:each).lazy.map{ |_m,_p,iter|
          iter
        }.find{|iter|
          iter[ActivityView::URI] == uri_string
        }
        selected_iter[ActivityView::ICON] = loaded_icon if selected_iter
      end
    }
  end

  activity_view = ActivityView.new(self)
  activity_view_sw = Gtk::ScrolledWindow.new.add activity_view
  activity_description = ::Gtk::IntelligentTextview.new
  activity_status = ::Gtk::Label.new
  activity_model_selector = Plugin::ActivityGtk::ModelSelector.new

  reset_activity(activity_view.model)

  # TODO: gtk3
  # activity_scroll_view.
  #   set_height_request(88)
  # activity_detail_view.
  #   set_height_request(128)

  tab(:activity, _("アクティビティ")) do
    set_icon Skin[:activity]
    activity_status.halign = :end
    detail_view = Gtk::Grid.new
      .tap { |w| w.orientation = :vertical }
      .add(Gtk::ScrolledWindow.new
        .tap do |w|
          w.expand = true
          w.hscrollbar_policy = :never
          w.vscrollbar_policy = :automatic
        end
        .add(activity_description))
      .add(activity_model_selector)
      .add(activity_status)

    nativewidget(
      Gtk::Paned.new(:vertical)
        .pack1(activity_view_sw, resize: true, shrink: true)
        .pack2(detail_view, resize: true, shrink: false)
    )
  end

  activity_view.ssc("cursor-changed") { |this|
    iter = this.selection.selected
    if iter
      activity_description.rewind(iter[ActivityView::MODEL].description)
      activity_status.set_text(iter[ActivityView::DATE])
      activity_model_selector.set(iter[ActivityView::MODEL].children)
    end
    false
  }

  # アクティビティ更新を受け取った時の処理
  # plugin, kind, title, icon, date, service
  on_modify_activity do |params|
    next if activity_view.destroyed?
    if not mute?(params)
      params = params.dup
      case params[:icon]
      when GdkPixbuf::Pixbuf
        # TODO: Pixbufを渡された時の処理
        params[:icon] = nil
      when Diva::Model, nil, false
      # nothing to do
      else
        params[:icon] = Plugin.collect(:photo_filter, params[:icon], Pluggaloid::COLLECT).first
      end
      # FIXME: gtk3
      activity_view.scroll_to_zero_lator! if activity_view.realized? and activity_view.vadjustment.value == 0.0
      model = Plugin::Activity::Activity.new(params)
      next if @contains_uris.include?(model.uri.to_s)
      @contains_uris << model.uri.to_s
      iter = activity_view.model.prepend
      if model.icon
        iter[ActivityView::ICON] = model.icon.load_pixbuf(width: 24, height: 24, &gen_icon_modifier(activity_view.model, model))
      end
      iter[ActivityView::KIND] = model.kind
      iter[ActivityView::TITLE] = model.title
      iter[ActivityView::DATE] = model.created.strftime('%Y/%m/%d %H:%M:%S')
      iter[ActivityView::MODEL] = model
      iter[ActivityView::URI] = model.uri.to_s
      if (UserConfig[:activity_show_timeline] || []).map(&:to_s).include?(model.kind)
        Plugin.call(:update, nil, [Mikutter::System::Message.new(description: model.description, source: model.plugin_slug.to_s, created: model.created)])
      end
      if (UserConfig[:activity_show_statusbar] || []).map(&:to_s).include?(model.kind)
        Plugin.call(:gui_window_rewindstatus, Plugin::GUI::Window.instance(:default), "#{model.kind}: #{model.title}", 10)
      end
    end
  end

  onunload do
    Addon.remove_tab _('アクティビティ')
  end

end
