# -*- coding: utf-8 -*-

module Gtk::FormDSL
  class SelectBuilder
    # ==== Args
    # [label_text] ラベルテキスト
    # [config_key] 設定のキー
    def initialize(formdsl, label_text, config_key, values = {}, mode: :auto)
      @formdsl = formdsl
      @label_text = label_text
      @config_key = config_key
      @options = values.to_a
      @mode = mode
    end

    # セレクトボックスに要素を追加する
    # ==== Args
    # [value] 選択されたらセットされる値
    # [text] ラベルテキスト。 _&block_ がなければ使われる。
    # [&block] Plugin::Settings のインスタンス内で評価され、そのインスタンスが内容として使われる
    def option(value, text = nil, &block)
      @options ||= []
      @options << if block
                    grid = @formdsl.create_inner_setting
                    grid.instance_eval(&block)
                    [value, text, grid].freeze
                  else
                    [value, text].freeze
                  end
      self
    end

    # optionメソッドで追加された項目をウィジェットに組み立てる
    # ==== Return
    # Array[Gtk::Widget]
    def build
      if @mode == :auto && !widget?
        build_combo
      else
        build_list
      end
    end

    def method_missing(*args, &block)
      @formdsl.method_missing(*args, &block)
    end

  private

    def widget?
      @options.any? { |_, _, w| w }
    end

    def build_combo
      label = Gtk::Label.new @label_text
      combo = Gtk::ComboBoxText.new
      @options.each { |_, text| combo.append text, text }
      _, combo.active_id = @options.find { |value,| value == @formdsl[@config_key] }
      combo.ssc :changed do
        @formdsl[@config_key], = @options[combo.active]
      end

      [label, combo]
    end

    def build_list
      list = Gtk::ListBox.new
      list.hexpand = true
      list.selection_mode = :none
      list.set_header_func do |row, before|
        before.nil? or next
        row.header = Gtk::Label.new.tap do |w|
          w.markup = "<b>#{@label_text}</b>"
          w.margin = 6
          w.margin_start = 12
          w.halign = :start
        end
      end
      list.ssc :row_activated do |_, row|
        row.child.each do |w|
          if w.is_a? Gtk::CheckButton
            w.clicked
          else
            w.can_focus? and w.has_focus = true
          end
        end
      end

      @group = Gtk::RadioButton.new
      @options.each do |value, text, widget|
        box = Gtk::Box.new(:vertical)
        box.margin = box.spacing = 12

        if widget
          # textの指定がなく、子widgetの中にLabelが1つだけ存在する場合は内容をRadioButtonに移動させる
          if text.nil?
            labels = widget.children.filter { |w| w.is_a?(Gtk::Label) }
            if labels.size == 1
              text = labels.first.label
              widget.remove(labels.first)
            end
          end
          box << build_check(value, text)

          widget.margin = 0
          widget.margin_start = 24
          box << widget
        else
          box << build_check(value, text)
        end

        list << box
      end

      [Gtk::Frame.new << list]
    end

    def build_check(value, text)
      Gtk::RadioButton.new(label: text, member: @group).tap do |w|
        @formdsl[@config_key] == value and w.active = true
        w.ssc(:toggled) { w.active? and @formdsl[@config_key] = value }
      end
    end
  end
end
