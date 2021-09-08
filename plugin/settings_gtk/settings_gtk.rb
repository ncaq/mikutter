# frozen_string_literal: true

module Plugin::SettingsGtk; end

require_relative 'menu'

Plugin.create :settings_gtk do
  on_open_setting do
    setting_window.show_all
  end

  def setting_window
    return @window if defined?(@window) and @window
    builder = Gtk::Builder.new
    s = (Pathname(__FILE__).dirname / 'settings.glade').to_s
    builder.add_from_file s
    @window = builder.get_object 'window'
    rect = { width: 256, height: 256 }
    @window.icon = Skin['settings.png'].load_pixbuf(**rect) do |pb|
      @window.destroyed? or @window.icon = pb
    end
    settings = builder.get_object 'settings'
    scrolled_menu = builder.get_object 'scrolled_menu'
    menu = Plugin::SettingsGtk::Menu.new
    scrolled_menu.add_with_viewport menu

    menu.ssc(:cursor_changed) do
      if menu.selection.selected
        active_iter = menu.selection.selected
        if active_iter
          settings.hide
          settings.children.each do |child|
            settings.remove(child)
            child.destroy
          end
          settings.add(active_iter[Plugin::SettingsGtk::Menu::COL_RECORD].widget).show_all
        end
      end
      false
    end

    @window.ssc(:destroy) do
      @window = nil
      false
    end

    @window
  end
end

