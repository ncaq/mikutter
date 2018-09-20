# -*- coding: utf-8 -*-
require 'observer'
miquire :mui, 'hierarchycal_selectbox'
require_relative 'model/setting'
require_relative 'option_widget'

module Plugin::Extract
end

class  Plugin::Extract::EditWindow < Gtk::Window
  attr_reader :extract

  # ==== Args
  # [extract] 抽出タブ設定 (Plugin::Extract::Setting)
  # [plugin] プラグインのインスタンス (Plugin)
  def initialize(extract, plugin)
    @plugin = plugin
    @extract = extract
    super(_('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME})

    notebook = Gtk::Notebook.new
    notebook.expand = true
    notebook.append_page(source_widget, Gtk::Label.new(_('データソース')))
    notebook.append_page(condition_widget, Gtk::Label.new(_('絞り込み条件')))
    notebook.append_page(option_widget, Gtk::Label.new(_('オプション')))
    add(Gtk::Grid.new
        .tap { |grid| grid.orientation = :vertical }
        .add(notebook)
        .add(ok_button.tap { |w| w.halign = :end }))
    ssc(:destroy) do
      @extract.notify_update
      false
    end
    set_size_request 480, 320
    show_all end

  def name
    @extract.name end

  def sexp
    @extract.sexp end

  def id
    @extract.id end

  def sources
    @extract.sources end

  def slug
    @extract.slug end

  def sound
    @extract.sound end

  def popup
    @extract.popup end

  def order
    @extract.order end

  def icon
    @extract.icon end

  def source_widget
    datasources = (Plugin.filtering(:extract_datasources, {}) || [{}]).first.map do |id, source_name|
      [id, source_name.is_a?(String) ? source_name.split('/'.freeze) : source_name] end
    datasources_box = Gtk::HierarchycalSelectBox.new(datasources, sources){
      modify_value sources: datasources_box.selected.to_a }
    @source_widget ||= Gtk::ScrolledWindow.new.add datasources_box
  end

  def condition_widget
    @condition_widget ||= Gtk::MessagePicker.new(sexp.freeze) do
      modify_value sexp: @condition_widget.to_a
    end.tap { |w| w.expand = true }
  end

  def option_widget
    Plugin::Extract::OptionWidget.new(@plugin, @extract) do
      input _('名前'), :name
      photoselect _('アイコン'), :icon, Skin.path, shortcuts: [Skin.default_dir, Skin.user_dir]
      settings _('通知') do
        fileselect _('サウンド'), :sound,
        dir: File.join(Skin.default_dir, 'sounds'),
        shortcuts: [File.join(Skin.default_dir, 'sounds')],
        filters: {_('非圧縮音声ファイル (*.wav, *.aiff)') => ['wav', 'WAV', 'aiff', 'AIFF'],
                  _('FLAC (*.flac, *.fla)') => ['flac', 'FLAC', 'fla', 'FLA'],
                  _('MPEG-1/2 Audio Layer-3 (*.mp3)') => ['mp3', 'MP3'],
                  _('Ogg (*.ogg)') => ['ogg', 'OGG'],
                  _('全てのファイル') => ['*']
                 }
        boolean _('ポップアップ'), :popup
      end
      select(_('並び順'), :order, Hash[Plugin.filtering(:extract_order, []).first.map{|o| [o.slug.to_s, o.name] }])
    end
  end

  def ok_button
    Gtk::Button.new(_('閉じる')).tap{ |button|
      button.ssc(:clicked){
        self.destroy } } end

  def refresh_title
    set_title _('%{name} - 抽出タブ - %{application_name}') % {name: name, application_name: Environment::NAME}
  end

  private

  def modify_value(new_values)
    @extract.merge(new_values)
    refresh_title
    @extract.notify_update
    self end

  def _(message)
    @plugin._(message) end

end
