# frozen_string_literal: true

module Plugin::SettingsGtk; end

require_relative 'menu'

Plugin.create :settings_gtk do
  on_open_setting do
    setting_window.show_all
  end

  def setting_window
    return @window if defined?(@window) and @window
    @window = window = ::Gtk::Window.new(_('設定'))
    window.set_size_request(320, 240)
    window.set_default_size(640, 480)
    menu = Plugin::SettingsGtk::Menu.new
    settings = ::Gtk::VBox.new
    scrolled = ::Gtk::ScrolledWindow.new.set_hscrollbar_policy(::Gtk::POLICY_NEVER)

    menu.ssc(:cursor_changed) do
      if menu.selection.selected
        active_iter = menu.selection.selected
        if active_iter
          settings.hide
          settings.children.each do |child|
            settings.remove(child)
            child.destroy
          end
          settings.closeup(active_iter[Plugin::SettingsGtk::Menu::COL_RECORD].widget).show_all
        end
      end
      false
    end

    window.ssc(:destroy) do
      @window = nil
      false
    end

    scrolled_menu = ::Gtk::ScrolledWindow.new.set_policy(::Gtk::POLICY_NEVER, ::Gtk::POLICY_AUTOMATIC)

    window.add(::Gtk::HPaned.new.add1(scrolled_menu.add_with_viewport(menu)).add2(scrolled.add_with_viewport(settings)))
  end
end

