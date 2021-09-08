# -*- coding: utf-8 -*-

require_relative 'edit_window'
require_relative 'extract_tab_list'

Plugin.create :extract_gtk do

  settings _("抽出タブ") do
    tablist = Plugin::ExtractGtk::ExtractTabList.new(Plugin[:extract])
    pack_start(Gtk::HBox.new.
               add(tablist).
               closeup(Gtk::VBox.new(false, 4).
                       closeup(Gtk::Button.new(Gtk::Stock::ADD).tap{ |button|
                                 button.ssc(:clicked) {
                                   Plugin.call :extract_tab_open_create_dialog
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::EDIT).tap{ |button|
                                 button.ssc(:clicked) {
                                   slug = tablist.selected_slug
                                   if slug
                                     Plugin.call(:extract_open_edit_dialog, slug)
                                   end
                                   true } }).
                       closeup(Gtk::Button.new(Gtk::Stock::DELETE).tap{ |button|
                                 button.ssc(:clicked) {
                                   slug = tablist.selected_slug
                                   if slug
                                     Plugin.call(:extract_tab_delete_with_confirm, slug)
                                   end
                                   true } })))
    add_tab_observer = on_extract_tab_create(&tablist.method(:add_record))
    update_tab_observer = on_extract_tab_update(&tablist.method(:update_record))
    delete_tab_observer = on_extract_tab_delete(&tablist.method(:remove_record))
    tablist.ssc(:destroy) do
      detach add_tab_observer
      detach update_tab_observer
      detach delete_tab_observer
    end
  end

  on_extract_tab_delete_with_confirm do |slug|
    extract = Plugin[:extract].extract_tabs[slug]
    if extract
      message = _("本当に抽出タブ「%{name}」を削除しますか？") % {name: extract.name}
      dialog = Gtk::MessageDialog.new(nil,
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::QUESTION,
                                      Gtk::MessageDialog::BUTTONS_YES_NO,
                                      message)
      dialog.run{ |response|
        if Gtk::Dialog::RESPONSE_YES == response
          Plugin.call :extract_tab_delete, slug end
        dialog.close } end end

  on_extract_tab_open_create_dialog do
    dialog = Gtk::Dialog.new(_("抽出タブを作成 - %{mikutter}") % {mikutter: Environment::NAME}, nil, nil,
                             [Gtk::Stock::OK, Gtk::Dialog::RESPONSE_ACCEPT],
                             [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_REJECT])
    prompt = Gtk::Entry.new
    dialog.vbox.
      add(Gtk::HBox.new(false, 8).
          closeup(Gtk::Label.new(_("名前"))).
          add(prompt).show_all)
    dialog.run{ |response|
      if Gtk::Dialog::RESPONSE_ACCEPT == response
        Plugin.call(:extract_tab_create, Plugin::Extract::Setting.new(name: prompt.text))
      end
      dialog.destroy
      prompt = dialog = nil } end

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
