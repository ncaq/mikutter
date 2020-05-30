# -*- coding: utf-8 -*-

=begin rdoc
UIを定義するためのDSLメソッドをクラスに追加するmix-in。
現在の値（初期値）を返す[]メソッドと、値が変更された時に呼ばれる[]=メソッドを定義すること。
includeするクラスはGtk::Gridでなければならない．
=end
module Gtk::FormDSL
  class Chainable
    def initialize(widget)
      @widget = widget
    end

    def tooltip(text)
      @widget.tooltip_text = text
      self
    end

    def native
      @widget
    end
  end

  extend Memoist

  PIXBUF_PHOTO_FILTER = Hash[GdkPixbuf::Pixbuf.formats.map{|f| ["#{f.description} (#{f.name})", f.extensions.flat_map{|x| [x.downcase.freeze, x.upcase.freeze] }.freeze] }].freeze
  PHOTO_FILTER = {'All images' => PIXBUF_PHOTO_FILTER.values.flatten}.merge(PIXBUF_PHOTO_FILTER).merge('All files' => ['*'])

  def initialize(*_)
    super

    type_strict self => Gtk::Grid
  end

  # 複数行テキスト
  # ==== Args
  # [label] ラベル
  # [config] キー
  def multitext(label, config)
    container = Gtk::HBox.new(false, 0)
    input = Gtk::TextView.new
    input.wrap_mode = Gtk::TextTag::WRAP_CHAR
    input.border_width = 2
    input.accepts_tab = false
    input.editable = true
    input.width_request = HYDE
    input.buffer.text = self[config] || ''
    container.pack_start(Gtk::Label.new(label), false, true, 0) if label
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(input), true, true, 0)
    input.buffer.ssc(:changed){ |widget|
      self[config] = widget.text
      false
    }
    add container
    container
  end

  # 特定範囲の数値入力
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [lower] 最低値。これより小さい数字は入力できないようになる
  # [upper] 最高値。これより大きい数字は入力できないようになる
  def adjustment(text, key, lower, upper)
    label = Gtk::Label.new text
    label.halign = :start

    value = (self[key] || lower).to_f
    lower, upper = lower.to_f, upper.to_f
    step = 1.0
    page, page_size = 5.0, 0.0
    adj = Gtk::Adjustment.new value, lower, upper, step, page, page_size
    adj.ssc :value_changed do
      self[key] = adj.value.to_i
      false
    end
    spinner = Gtk::SpinButton.new adj, 0, 0
    spinner.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to spinner, label, :right, 1, 1

    Chainable.new spinner
  end

  # 真偽値入力
  # ==== Args
  # [text] チェックボックスのラベルテキスト
  # [key] キー
  def boolean(text, key)
    check = Gtk::CheckButton.new text
    check.active = self[key]
    check.ssc :toggled do
      self[key] = check.active?
      false
    end

    attach_next_to check, nil, :bottom, 2, 1

    Chainable.new check
  end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] キー
  # [dir] 初期のディレクトリ
  # [title:] ファイル選択ダイアログのタイトル(String)
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  # [filters:] ファイル選択ダイアログの拡張子フィルタ(Hash)。キーはコンボボックスに表示するラベル(String)、値は拡張子の配列(Array)。拡張子はStringで指定する。
  # [use_preview:] ファイル選択ダイアログで、ファイルのプレビューを表示するか。 _true_ なら表示する。 (_true_ or _false_)
  def fileselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s, shortcuts: [], filters: {}, use_preview: false)
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_OPEN, title: title, shortcuts: shortcuts, filters: filters, use_preview: use_preview)
  end

  # ファイルを選択する
  # ==== Args
  # [label] ラベル
  # [config] キー
  # [dir] 初期のディレクトリ
  # [title:] ファイル選択ダイアログのタイトル(String)
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  # [filters:] ファイル選択ダイアログの拡張子フィルタ(Hash)。キーはコンボボックスに表示するラベル(String)、値は拡張子の配列(Array)。拡張子はStringで指定する。
  # [use_preview:] ファイル選択ダイアログで、ファイルのプレビューを表示するか。 _true_ なら表示する。 (_true_ or _false_)
  def photoselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s, shortcuts: [], filters: nil, use_preview: true)
    fs_photoselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_OPEN, title: title, shortcuts: shortcuts, filters: filters || PHOTO_FILTER, use_preview: use_preview)
  end

  # ディレクトリを選択する
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [current] 初期のディレクトリ
  # [title:] ファイル選択ダイアログのタイトル(String)
  # [shortcuts:] ファイル選択ダイアログのサイドバーに表示しておくディレクトリの絶対パスの配列(Array)
  def dirselect(label, config, _current=Dir.pwd, dir: _current, title: label.to_s, shortcuts: [])
    fsselect(label, config, dir: dir, action: Gtk::FileChooser::ACTION_SELECT_FOLDER, title: title, shortcuts: shortcuts)
  end

  # 一行テキストボックス
  # ==== Args
  # [text] ラベルテキスト
  # [key] キー
  def input(text, key, action=nil)
    widget_right = entry = build_entry(key)

    if action
      # TODO; gtk3 case action
      button = Gtk::Button.new
      button.image = Gtk::Image.new icon_name: 'edit-paste-symbolic'
      button.ssc :clicked do
        get_clipboard(Gdk::Selection::CLIPBOARD)
          .request_text { |_, text| entry.text = text }
      end

      box = Gtk::Box.new(:horizontal).apply do
        style_context.add_class :linked
        add entry, expand: true
        add button
      end
      widget_right = box
    end

    widget_right.halign = :fill
    widget_right.hexpand = true

    if text
      label = Gtk::Label.new text
      label.halign = :start

      # attach to a new row of the grid
      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to widget_right, label, :right, 1, 1
    else
      # attach to a new row of the grid
      attach_next_to widget_right, nil, :bottom, 2, 1
    end

    Chainable.new widget_right
  end

  # 一行テキストボックス(非表示)
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def inputpass(text, key)
    entry = build_entry(key)
    entry.visibility = false
    entry.halign = :fill
    entry.hexpand = true

    if text
      label = Gtk::Label.new text
      label.halign = :start

      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to entry, label, :right, 1, 1
    else
      attach_next_to entry, nil, :bottom, 2, 1
    end

    Chainable.new entry
  end

  # 複数テキストボックス
  # 任意個の項目を入力させて、配列で受け取る。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  def multi(label, config)
    settings(label) do
      container, box = Gtk::HBox.new(false, 0), Gtk::VBox.new(false, 0)
      input_ary = []
      btn_add = Gtk::Button.new(Gtk::Stock::ADD)
      array_converter = lambda {
        c = self[config] || []
        (c.is_a?(Array) ? c : [c]).compact }
      add_button = lambda { |content|
        input = Gtk::Entry.new
        input.text = content.to_s
        input.ssc(:changed) { |w|
          self[config] = w.parent.children.map(&:text).compact
          false
        }
        input.ssc(:focus_out_event){ |w|
          w.parent.remove(w) if w.text.empty?
          false
        }
        box.closeup input
        input
      }
      input_ary = array_converter.call.each(&add_button)
      btn_add.ssc(:clicked) { |w|
        w.get_ancestor(Gtk::Window).set_focus(add_button.call("").show)
        false
      }
      container.pack_start(box, true, true, 0)
      container.pack_start(Gtk::Alignment.new(1.0, 1.0, 0, 0).add(btn_add), false, true, 0)
      add container
      container
    end
  end

  # 設定のグループ。関連の強い設定をカテゴライズできる。
  # ==== Args
  # [title] ラベル
  # [&block] ブロック
  def settings(title, &block)
    @headings ||= []
    @headings << title

    label = Gtk::Label.new @headings.map { |s| "<b>#{s}</b>" }.join ' > '
    label.use_markup = true
    label.halign = :start
    attach_next_to label, nil, :bottom, 2, 1

    instance_eval(&block)
    @headings.pop

    Chainable.new label
  end

  # 〜についてダイアログを出すためのボタン。押すとダイアログが出てくる
  # ==== Args
  # [text] ラベルテキスト
  # [options]
  #   設定値。以下のキーを含むハッシュ。
  #   _:name_ :: ソフトウェア名
  #   _:version_ :: バージョン
  #   _:copyright_ :: コピーライト
  #   _:comments_ :: コメント
  #   _:license_ :: ライセンス
  #   _:website_ :: Webページ
  #   _:logo_ :: ロゴ画像。 フルパス(String)か、Photo Modelか、GdkPixbuf::Pixbufを指定する
  #   _:authors_ :: 作者の名前。通常MastodonのAcct（Array）
  #   _:artists_ :: デザイナとかの名前。通常MastodonのAcct（Array）
  #   _:documenters_ :: ドキュメントかいた人とかの名前。通常MastodonのAcct（Array）
  def about(text, options={})
    name_mapper = Hash.new{|h,k| k }
    name_mapper[:name] = :program_name

    button = Gtk::Button.new label: text
    button.hexpand = true
    button.signal_connect(:clicked){
      dialog = Gtk::AboutDialog.new.show
      options.each { |key, value|
        dialog.__send__("#{name_mapper[key]}=", about_converter[key][value])
      }
      dialog.signal_connect(:response){
        dialog.destroy
        false
      }
    }

    attach_next_to button, nil, :bottom, 2, 1

    Chainable.new button
  end

  # フォントを決定させる。押すとフォント、サイズを設定するダイアログが出てくる。
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def font(text, key)
    label = Gtk::Label.new text
    label.halign = :start
    font = build_font(key)
    font.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to font, label, :right, 1, 1

    Chainable.new font
  end

  # 色を決定させる。押すと色を設定するダイアログが出てくる。
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  def color(text, key)
    label = Gtk::Label.new text
    label.halign = :start
    color = build_color(key)
    color.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to color, label, :right, 1, 1

    Chainable.new color
  end

  # フォントと色を決定させる。
  # ==== Args
  # [text] ラベルテキスト
  # [font_key] フォントの設定のキー
  # [color_key] 色の設定のキー
  def fontcolor(text, font_key, color_key)
    label = Gtk::Label.new text
    label.halign = :start
    right_container = Gtk::Grid.new.tap do |grid|
      grid.column_spacing = 6
      grid << (build_font font_key)
      grid << (build_color color_key)
    end
    right_container.halign = :end

    attach_next_to label, nil, :bottom, 1, 1
    attach_next_to right_container, label, :right, 1, 1

    Chainable.new right_container
  end

  # リストビューを表示する。
  # ==== Args
  # [label] ラベル
  # [config] 設定のキー
  # [columns:]
  #   配列の配列で、各要素は[カラムのタイトル(String), カラムの表示文字を返すProc]
  # [reorder:]
  #   _true_ なら、ドラッグ＆ドロップによる並び替えを許可する
  # [&block] 内容
  def listview(config, columns:, edit: true, reorder: edit, object_initializer: :itself.to_proc, &generate)
    listview = Gtk::FormDSL::ListView.new(
      self, columns, config, object_initializer,
      create: edit,
      update: edit,
      delete: edit,
      reorder: reorder,
      &generate)
    pack_start(Gtk::VBox.new(false, 4).
                 #closeup(listview.filter_entry).
                 add(Gtk::HBox.new(false, 4).
                       add(listview)
                       .closeup(listview.buttons(Gtk::VBox))
                    ))
  end

  # 要素を１つ選択させる
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def select(text, key, default = {}, mode: :auto, **kwrest, &block)
    builder = SelectBuilder.new self, text, key, default.merge(kwrest), mode: mode
    block and builder.instance_eval(&block)
    widgets = builder.build

    if widgets.size == 1
      list, = widgets

      attach_next_to list, nil, :bottom, 2, 1

      Chainable.new list
    else
      label, combo = widgets
      label.halign = :start
      label.hexpand = true

      attach_next_to label, nil, :bottom, 1, 1
      attach_next_to combo, label, :right, 1, 1

      Chainable.new combo
    end
  end

  # 要素を複数個選択させる
  # ==== Args
  # [text] ラベルテキスト
  # [key] 設定のキー
  # [default]
  #   連想配列で、 _値_ => _ラベル_ の形式で、デフォルト値を与える。
  #   _block_ と同時に与えれられたら、 _default_ の値が先に入って、 _block_ は後に入る。
  # [&block] 内容
  def multiselect(text, key, default = {}, &block)
    builder = MultiSelectBuilder.new self, text, key, default
    block and builder.instance_eval(&block)
    list, = builder.build

    attach_next_to list, nil, :bottom, 2, 1

    Chainable.new list
  end

  def keybind(title, config)
    keyconfig = Gtk::KeyConfig.new(title, self[config] || "")
    container = Gtk::HBox.new(false, 0)
    container.pack_start(Gtk::Label.new(title), false, true, 0)
    container.pack_start(Gtk::Alignment.new(1.0, 0.5, 0, 0).add(keyconfig), true, true, 0)
    keyconfig.change_hook = ->(modify) { self[config] = modify }
    closeup(container)
    container
  end

  # 引数のテキストを表示する。
  def label(text)
    Gtk::Label.new(text).apply do
      self.halign = :start
      self.wrap = true
      self.xalign = 0
    end.tap do |label|
      attach_next_to label, nil, :bottom, 2, 1
    end
  end

  # 引数のテキストを表示する。
  def markup(text)
    Gtk::Label.new.apply do
      self.halign = :start
      self.wrap = true
      self.markup = text
      self.xalign = 0
    end.tap do |label|
      attach_next_to label, nil, :bottom, 2, 1
    end
  end

  # Diva::Model の内容を表示する。
  # 通常はボタンとして描画され、クリックするとopenイベントが発生する。
  # エレメントとして値を更新する機能はない。
  # ==== Args
  # 以下のいずれか
  # [String | Diva::URI] URLを表示する
  # [Diva::Model]
  #   _target.title_ がラベルになる。
  #   _target.icon_ が呼び出せてPhotoModelを返す場合は、それも表示する。
  def link(target)
    case target
    when String, URI, Addressable::URI, Diva::URI
      button = Gtk::Button.new(target.to_s, false)
      button.
        tooltip(target.to_s).
        set_alignment(0.0, 0.5).
        ssc(:clicked, &model_opener(target))
      add button
    when Diva::Model
      button = Gtk::Button.new
      box = Gtk::HBox.new
      if target.respond_to?(:icon)
        icon = Gtk::WebIcon.new(target.icon, 48, 48)
        box.closeup(icon)
      end
      button.
        tooltip(target.title).
        add(box.add(Gtk::Label.new(target.title))).
        ssc(:clicked, &model_opener(target))
      add button
    end
  end

  # settingsメソッドとSelectから内部的に呼ばれるメソッド。Groupの中に入れるGtkウィジェットを返す。
  # 戻り値は同時にこのmix-inをロードしている必要がある。
  def create_inner_setting
    self.new()
  end

  def method_missing(*args, &block)
    @plugin.__send__(*args, &block)
  end

private

  def build_entry(key)
    entry = Gtk::Entry.new
    entry.text = self[key] || ''
    entry.ssc :changed do
      self[key] = entry.text
      false
    end
    entry
  end

  def about_converter
    Hash.new(ret_nth).merge!(
      logo: -> value {
        case value
        when GdkPixbuf::Pixbuf
          value
        when Diva::Model
          value.pixbuf(width: 48, height: 48)
        else
          Plugin.collect(:photo_filter, value, Pluggaloid::COLLECT).first.pixbuf(width: 48, height: 48) rescue nil
        end
      }
    )
  end
  memoize :about_converter

  def build_font(key)
    s = self[key]
    font = Gtk::FontButton.new(*(s ? [s] : []))
    font.ssc(:font_set) { self[key] = font.font_name }
    font
  end

  def build_color(key)
    a = self[key]

    # migration from Gdk::Color to Gdk::RGBA
    a.first.is_a? Integer and a = self[key] = a.map { |i| i.to_f / 65_536 }

    color = Gtk::ColorButton.new(*(a ? [Gdk::RGBA.new(*a)] : []))
    color.ssc(:color_set) { self[key] = color.rgba.to_a[0, 3] }
    color
  end

  def fsselect(label, config, dir: Dir.pwd, action: Gtk::FileChooser::ACTION_OPEN, title: label, shortcuts: [], filters: {}, use_preview: false)
    input = input(label, config).native
    button = Gtk::Button.new(Plugin[:settings]._('参照'))
    button.signal_connect(:clicked, &gen_fileselect_dialog_generator(title, action, dir, config: config, shortcuts: shortcuts, filters: filters, use_preview: use_preview, &input.method(:text=)))
    Gtk::Box.new(:horizontal).apply do
      style_context.add_class :linked
      add input
      add button
    end
  end

  def fs_photoselect(label, config, dir: Dir.pwd, action: Gtk::FileChooser::ACTION_OPEN, title: label, width: 64, height: 32, shortcuts: [], filters: {}, use_preview: true)
    widgets = fs_photo_create_widgets(
      photo: fs_photo_thumbnail(self[config]),
      width: width,
      height: height,
      label: label,
      config: config)
    fs_photo_packing_widgets(**widgets)
    fs_photo_handle_widgets(
      config: config,
      title: title,
      action: action,
      dir: dir,
      width: width,
      height: height,
      shortcuts: shortcuts,
      filters: filters,
      use_preview: use_preview,
      **widgets)
    widgets[:container]
  end

  def fs_photo_create_widgets(label:, config:, photo:, width:, height:)
    container = input(label, config)
    { container: container,
      path: container.children.last.children.first,
      image: Gtk::WebIcon.new(photo, width, height),
      image_container: Gtk::EventBox.new,
      button: Gtk::Button.new(Plugin[:settings]._('参照')) }
  end

  def fs_photo_packing_widgets(container:, image:, image_container:, button:, **kwrest)
    image_container.visible_window = false
    image_container.add(image)
    container.pack_start(image_container, false)
    container.pack_start(button, false)
  end

  def fs_photo_handle_widgets(config:, title:, action:, dir:, width:, height:, image_container:, button:, path:, image:, shortcuts:, filters:, use_preview:, **kwrest)
    image_container.ssc(:button_press_event) do |w, event|
      Plugin.call(:open, fs_photo_thumbnail(path.text) || path.text) if event.button == 1
      false
    end
    image_container.ssc :enter_notify_event do |w|
      w.window.cursor = Gdk::Cursor.new 'pointer'
      false
    end
    image_container.ssc :leave_notify_event do |w|
      w.window.cursor = Gdk::Cursor.new 'default'
      false
    end
    button.signal_connect(:clicked, &gen_fileselect_dialog_generator(title, action, dir, config: config, shortcuts: shortcuts, filters: filters, use_preview: use_preview, &path.method(:text=)))
    path.signal_connect(:changed) do |w|
      image.load_model(fs_photo_thumbnail(w.text), Gdk::Rectangle.new(0, 0, width, height))
      false
    end
  end

  def fs_photo_thumbnail(path)
    Plugin.collect(:photo_filter, path, Pluggaloid::COLLECT).first
  end

  def gen_fileselect_dialog_generator(title, action, dir, config:, shortcuts: [], filters: {}, use_preview: false, &result_callback)
    ->(widget) do
      dialog = Gtk::FileChooserDialog.new(title,
                                          widget.get_ancestor(Gtk::Window),
                                          action,
                                          nil,
                                          [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                                          [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
      dialog.current_folder = File.expand_path(dir)

      filters.each do |name, exts|
        filter = Gtk::FileFilter.new
        filter.name = name
        exts.each do |ext|
          filter.add_pattern("*.#{ext}")
        end
        dialog.add_filter(filter)
      end

      shortcuts.select { |dir|
        !dialog.shortcut_folders.include?(dir)
      }.each do |dir|
        dialog.add_shortcut_folder(dir)
      rescue => e
        puts e
        puts e.backtrace
      end

      if use_preview
        preview = Gtk::Image.new
        dialog.preview_widget = preview
        dialog.ssc(:update_preview) do
          path = dialog.preview_filename
          pixbuf = Gdk::Pixbuf.new(file: path, width: 256, height: 256)
          preview.set_pixbuf(pixbuf)
          dialog.set_preview_widget_active(true)
        rescue => e
          dialog.set_preview_widget_active(false)
        end
      end

      dialog.ssc_atonce(:response, self, &gen_fs_dialog_response_callback(config, &result_callback))
      dialog.show_all
      false
    end
  end

  def gen_fs_dialog_response_callback(config, &result_callback)
    ->(widget, response_id) do
      case response_id
      when Gtk::Dialog::RESPONSE_ACCEPT
        self[config] = widget.filename
        result_callback.(widget.filename)
      end
      widget.destroy
    end
  end

  def model_opener(model)
    ->(*args) do
      Plugin.call(:open, model)
      true
    end
  end
end

require 'mui/gtk_form_dsl_select'
require 'mui/gtk_form_dsl_multi_select'
require 'mui/gtk_form_dsl_listview'
