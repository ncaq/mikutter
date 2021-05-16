# -*- coding: utf-8 -*-

require_relative 'setting_dsl'

module Plugin::SettingsGtk
  # 設定DSLで設定された設定をリストアップし、選択するリストビュー。
  class Menu < Gtk::TreeView
    COL_LABEL = 0
    COL_RECORD = 1
    COL_ORDER = 2

    def initialize
      super(Gtk::TreeStore.new(String, Record, Integer))
      set_headers_visible(false)
      model.set_sort_column_id(COL_ORDER, Gtk::SORT_ASCENDING)
      column = Gtk::TreeViewColumn.new("", ::Gtk::CellRendererText.new, text: 0)
      self.append_column(column)
      self.set_width_request(HYDE)
      insert_defined_settings
    end

    private
    def record_order
      UserConfig[:settings_menu_order] || ["基本設定", "入力", "表示", "通知", "ショートカットキー", "アクティビティ", "アカウント情報"]
    end

    def insert_defined_settings
      Plugin.collect(:settings).to_a.each do |phantom|
        add_record(Record.new(phantom))
      end
    end

    def add_record(record, parent: nil)
      iter = model.append(parent)
      iter[COL_LABEL] = record.name
      iter[COL_RECORD] = record
      iter[COL_ORDER] = (record_order.index(record.name) || record_order.size)
      Delayer.new do
        next if destroyed?
        record.children.deach do |child_record|
          break if destroyed?
          add_record(child_record, parent: iter)
        end
      end
    end
  end

  class Record
    extend Memoist

    def initialize(phantom)
      @phantom = phantom
    end

    def name
      @phantom.title
    end

    def widget
      box = Plugin::SettingsGtk::SettingDSL.new(@phantom.plugin)
      box.instance_eval(&@phantom)
      box
    end

    def children
      @phantom.children.map { |child| Record.new(child) }
    end

    def inspect
      "#<#{self.class}: #{name.inspect}>"
    end
  end
end
