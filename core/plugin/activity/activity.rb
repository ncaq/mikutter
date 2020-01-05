# -*- coding: utf-8 -*-
# 通知管理プラグイン

miquire :mui, 'tree_view_pretty_scroll'
miquire :lib, 'reserver'

require_relative 'model/activity'
require_relative 'model_selector'
require "set"

# アクティビティの設定の並び順
UserConfig[:activity_kind_order] = nil unless UserConfig[:activity_kind_order].is_a? Array
UserConfig[:activity_kind_order] ||= %w(
	retweet
	favorite
	follow
	list_member_added
	list_member_removed
	dm
	system
	ratelimit
	streaming_status
	error)
# アクティビティタブに保持する通知の数
UserConfig[:activity_max] ||= 1000

Plugin.create(:activity) do

  class ActivityView < ::Gtk::CRUD
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
      @creatable = @updatable = @deletable = false
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

  BOOT_TIME = Time.new.freeze
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
    Reserver.new(60, thread: Delayer) do
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

  def gen_listener_for_visible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ UserConfig[uc].include?(kind) rescue false },
      set: ->(value) do
        if value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

  def gen_listener_for_invisible_check(uc, kind)
    UserConfig[uc] ||= []
    Plugin::Settings::Listener.new \
      get: ->(){ (not UserConfig[uc].include?(kind)) rescue true },
      set: ->(value) do
        unless value
          UserConfig[uc] += [kind]
        else
          UserConfig[uc] -= [kind] end end end

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

  # 新しいアクティビティの種類を定義する。設定に表示されるようになる
  # ==== Args
  # [kind] 種類
  # [name] 表示する名前
  defdsl :defactivity do |kind, name|
    kind, name = kind.to_sym, name.to_s
    filter_activity_kind do |data|
      data[kind] = name
      [data] end end

  activity_view = ActivityView.new(self)
  activity_view_sw = Gtk::ScrolledWindow.new.add activity_view
  activity_description = ::Gtk::IntelligentTextview.new
  activity_status = ::Gtk::Label.new
  activity_model_selector = Plugin::Activity::ModelSelector.new

  reset_activity(activity_view.model)

  # TODO: gtk3
  # activity_scroll_view.
  #   set_height_request(88)
  # activity_detail_view.
  #   set_height_request(128)

  tab(:activity, _("アクティビティ")) do
    set_icon Skin['activity.png']
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
        .pack1(activity_view_sw, true, true)
        .pack2(detail_view, true, false)
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
        params[:icon] = Enumerator.new{|y|
          Plugin.filtering(:photo_filter, params[:icon], y)
        }.first
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

  on_favorite do |service, user, message|
    activity(:favorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} がふぁぼふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}"),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service,
             children: [user, message, message.user])
  end

  on_unfavorite do |service, user, message|
    activity(:unfavorite, "#{message.user[:idname]}: #{message.to_s}",
             description:(_("@%{user} があんふぁぼしました") % {user: user[:idname]} + "\n" +
                          "@#{message.user[:idname]}: #{message.to_s}"),
             icon: user.icon,
             related: message.user.me? || user.me?,
             service: service,
             children: [user, message, message.user])
  end

  on_retweet do |retweets|
    retweets.each { |retweet|
      retweet.retweet_source_d.next{ |source|
        activity(:retweet, retweet.to_s,
                 description:(_("@%{user} がリツイートしました") % {user: retweet.user[:idname]} + "\n" +
                              "@#{source.user[:idname]}: #{source.to_s}"),
                 icon: retweet.user.icon,
                 date: retweet[:created],
                 related: (retweet.user.me? || source && source.user.me?),
                 service: Service.primary,
                 children: [retweet.user, source, source.user]) }.terminate(_ 'リツイートソースが取得できませんでした') }
  end

  on_list_member_added do |service, user, list, source_user|
    title = _("@%{user}が%{list}に追加されました") % {
      user: user[:idname],
      list: list[:full_name] }
    desc_by_user = {
      description: list[:description],
      user: list.user[:idname] }
    activity(:list_member_added, title,
             description:("#{title}\n" +
                          _("%{description} (by @%{user})") % desc_by_user + "\n" +
                          "https://twitter.com/#{list.user[:idname]}/#{list[:slug]}"),
             icon: user.icon,
             related: user.me? || source_user.me?,
             service: service,
             children: [user, list, list.user])
  end

  on_list_member_removed do |service, user, list, source_user|
    title = _("@%{user}が%{list}から削除されました") % {
      user: user[:idname],
      list: list[:full_name] }
    desc_by_user = {
      description: list[:description],
      user: list.user[:idname] }
    activity(:list_member_removed, title,
             description:("#{title}\n"+
                          _("%{description} (by @%{user})") % desc_by_user + "\n" +
                          "https://twitter.com/#{list.user[:idname]}/#{list[:slug]}"),
             icon: user.icon,
             related: user.me? || source_user.me?,
             service: service,
             children: [user, list, list.user])
  end

  on_follow do |by, to|
    by_user_to_user = {
      followee: by[:idname],
      follower: to[:idname] }
    activity(:follow, _("@%{followee} が @%{follower} をﾌｮﾛｰしました") % by_user_to_user,
             related: by.me? || to.me?,
             icon: (to.me? ? by : to).icon,
             children: [by, to])
  end

  on_direct_messages do |service, dms|
    dms.each{ |dm|
      date = dm[:created]
      if date > BOOT_TIME
        activity(:dm, dm[:text],
                 description:
                   [ _('差出人: @%{sender}') % {sender: dm[:sender].idname},
                     _('宛先: @%{recipient}') % {recipient: dm[:recipient].idname},
                     '',
                     dm[:text]
                   ].join("\n"),
                 icon: dm[:sender].icon,
                 service: service,
                 date: date,
                 children: [dm.recipient, dm.sender, dm]) end }
  end

  onunload do
    Addon.remove_tab _('アクティビティ')
  end

  settings _("アクティビティ") do
    activity_kind = Plugin.filtering(:activity_kind, {})
    activity_kind_order = TypedArray(String).new
    if activity_kind
      activity_kind = activity_kind.last
      activity_kind.keys.each{ |kind|
        kind = kind.to_s
        i = where_should_insert_it(kind, activity_kind_order, UserConfig[:activity_kind_order])
        activity_kind_order.insert(i, kind) }
    else
      activity_kind_order = []
      activity_kind = {} end

    activity_kind_order.each do |kind|
      name = activity_kind[kind.to_sym]
      ml_param = {name: name}
      settings name do
        boolean(_('%{name}を表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind, kind)).tooltip(_('%{name}を、アクティビティタイムラインに表示します。チェックを外すと、%{name}の他の設定は無効になります。') % ml_param)
        boolean(_('自分に関係ない%{name}も表示する') % ml_param, gen_listener_for_invisible_check(:activity_mute_kind_related, kind)).tooltip(_('自分に関係ない%{name}もアクティビティタイムラインに表示されるようになります。チェックを外すと、自分に関係ない%{name}は表示されません。') % ml_param)
        boolean(_('タイムラインに表示'), gen_listener_for_visible_check(:activity_show_timeline, kind)).tooltip(_('%{name}が通知された時に、システムメッセージで%{name}を通知します') % ml_param)
        boolean(_('ステータスバーに表示'), gen_listener_for_visible_check(:activity_show_statusbar, kind)).tooltip(_('%{name}が通知された時に、ステータスバーにしばらく表示します') % ml_param)
      end
    end
  end

  defactivity :retweet, _("リツイート")
  defactivity :favorite, _("ふぁぼ")
  defactivity :follow, _("フォロー")
  defactivity :list_member_added, _("リストに追加")
  defactivity :list_member_removed, _("リストから削除")
  defactivity :dm, _("ダイレクトメッセージ")
  defactivity :system, _("システムメッセージ")
  defactivity :error, _("エラー")

end
