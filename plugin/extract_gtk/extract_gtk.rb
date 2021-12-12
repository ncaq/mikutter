# frozen_string_literal: true

require_relative 'edit_window'
require_relative 'extract_tab_list'

Plugin.create :extract_gtk do
  settings _("抽出タブ") do
    tablist = Plugin::ExtractGtk::ExtractTabList.new(Plugin[:extract])
    tablist.hexpand = true
    tablist.vexpand = true

    btn_add = Gtk::Button.new(stock_id: Gtk::Stock::ADD)
    btn_edit = Gtk::Button.new(stock_id: Gtk::Stock::EDIT)
    btn_delete = Gtk::Button.new(stock_id: Gtk::Stock::DELETE)
    btn_add.ssc(:clicked) do
      Plugin.call(:extract_tab_open_create_dialog, toplevel)
      true
    end
    btn_edit.ssc(:clicked) do
      slug = tablist.selected_slug
      Plugin.call(:extract_open_edit_dialog, slug) if slug
      true
    end
    btn_delete.ssc(:clicked) do
      slug = tablist.selected_slug
      Plugin.call(:extract_tab_delete_with_confirm, toplevel, slug) if slug
      true
    end

    grid = Gtk::Grid.new
    grid.column_spacing = 6
    grid << Gtk::ScrolledWindow.new.add(tablist)
    grid << Gtk::Grid.new.tap do |grid|
      grid.orientation = :vertical
      grid.row_spacing = 6
      grid << btn_add << btn_edit << btn_delete
    end

    add grid

    add_tab_observer = on_extract_tab_create(&tablist.method(:add_record))
    update_tab_observer = on_extract_tab_update(&tablist.method(:update_record))
    delete_tab_observer = on_extract_tab_delete(&tablist.method(:remove_record))
    tablist.ssc(:destroy) do
      detach add_tab_observer
      detach update_tab_observer
      detach delete_tab_observer
    end
  end

  on_extract_tab_delete_with_confirm do |window, slug|
    extract = Plugin[:extract].extract_tabs[slug]
    extract or next

    message = _("本当に抽出タブ「%{name}」を削除しますか？") % {name: extract.name}

    dialog = Gtk::MessageDialog.new(parent: window,
                                    type: :question,
                                    buttons: :none,
                                    message: message)
    dialog.add_button Gtk::Stock::CANCEL, :reject
    btn_remove = dialog.add_button Gtk::Stock::REMOVE, :accept
    btn_remove.style_context.add_class 'destructive-action'
    case dialog.run
    when Gtk::ResponseType::ACCEPT
      Plugin.call(:extract_tab_delete, slug)
    end
    dialog.destroy
  end

  on_extract_tab_open_create_dialog do |window|
    builder = Gtk::Builder.new
    s = (Pathname(__FILE__).dirname / 'extract_settings.glade').to_s
    builder.add_from_file s

    title = _("抽出タブを作成 - %{mikutter}") % {mikutter: Environment::NAME}

    dialog = builder.get_object('dlg_add')
    dialog.title = title
    dialog.set_transient_for window
    builder.get_object('dlg_add_label').text = _('名前')
    entry = builder.get_object 'dlg_add_entry'

    case dialog.run
    when Gtk::ResponseType::ACCEPT
      Plugin.call(:extract_tab_create, Plugin::Extract::Setting.new(name: entry.text))
    end
    dialog.destroy
  end

  on_extract_open_edit_dialog do |extract_slug|
    window = ::Plugin::ExtractGtk::EditWindow.new(Plugin[:extract].extract_tabs[extract_slug], self)
    event = on_extract_tab_update do |setting|
      if extract_slug == setting.slug && !window.destroyed?
        window.refresh_title
      end
    end
    window.ssc(:destroy) do
      event.detach
      false
    end
  end
end
