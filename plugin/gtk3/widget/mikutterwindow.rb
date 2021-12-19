# -*- coding: utf-8 -*-

require 'pathname'

# PostBoxや複数のペインを持つWindow
module Plugin::Gtk3
  class MikutterWindow < Gtk::Window

    attr_reader :panes, :statusbar

    def initialize(imaginally, plugin)
      type_strict plugin => Plugin
      super()

      @imaginally = imaginally
      @plugin = plugin

      @container = Gtk::Box.new(:vertical, 0)
      @panes = Gtk::Grid.new.tap do |panes|
        panes.column_spacing = 6
        panes.column_homogeneous = true
      end
      header = Gtk::Box.new(:horizontal, 0)
      @postboxes = Gtk::Box.new(:vertical, 0)

      header.pack_start(WorldShifter.new, expand: false)
        .pack_start(@postboxes, expand: true, fill: true)

      @container.pack_start(header, expand: false)
        .pack_start(@panes, expand: true, fill: true)
        .pack_start(create_statusbar, expand: false)

      add(@container)

      set_size_request(240, 240)

      Plugin[:gtk3].on_userconfig_modify do |key, newval|
        refresh if key == :postbox_visibility
      end
      Plugin[:gtk3].on_world_after_created do |new_world|
        refresh
      end
      Plugin[:gtk3].on_world_destroy do |deleted_world|
        refresh
      end
    end

    def add_postbox(i_postbox)
      options = {postboxstorage: @postboxes, delegate_other: true}.merge(i_postbox.options||{})
      if options[:delegate_other]
        i_window = i_postbox.ancestor_of(Plugin::GUI::Window)
        options[:delegate_other] = postbox_delegation_generator(i_window) end
      postbox = Gtk::PostBox.new(**options)
      @postboxes.add postbox
      set_focus(postbox.post) unless options[:delegated_by]
      postbox.no_show_all = false
      postbox.show_all if visible?
      postbox end

    private

    def postbox_delegation_generator(window)
      ->(params) do
        postbox = Plugin::GUI::Postbox.instance
        postbox.options = params
        window << postbox end end

    def refresh
      @postboxes.children.each(&(visible? ? :show_all : :hide))
    end

    # ステータスバーを返す
    # ==== Return
    # Gtk::Statusbar
    def create_statusbar
      statusbar = Gtk::Statusbar.new
      statusbar.push(statusbar.get_context_id("system"), @plugin._("Statusbar default message"))
      @statusbar = statusbar.pack_start(status_button(Gtk::Box.new(:horizontal)), expand: false)
    end

    # ステータスバーに表示するWindowレベルのボタンを _container_ にpackする。
    # 返された時点では空で、後からボタンが入る(showメソッドは自動的に呼ばれる)。
    # ==== Args
    # [container] packするコンテナ
    # ==== Return
    # container
    def status_button(container)
      current_world, = Plugin.filtering(:world_current, nil)
      ToolbarGenerator.generate(
        container,
        Plugin::GUI::Event.new(
          event: :window_toolbar,
          widget: @imaginally,
          messages: [],
          world: current_world
        ),
        :window
      )
    end

    def visible?
      case UserConfig[:postbox_visibility]
      when :always
        true
      when :auto
        !!Plugin.collect(:worlds).first
      else
        false
      end
    end

  end
end
