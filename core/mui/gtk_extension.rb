# -*- coding: utf-8 -*-
require 'userconfig'

require 'gtk3'
require 'monitor'
require_if_exist 'Win32API'

class GLib::Instantiatable
  # signal_connectと同じだが、イベントが呼ばれるたびにselfが削除されたGLib Objectでない場合のみブロックを実行する点が異なる。
  # また、relatedの中に既に削除されたGLib objectがあれば、ブロックを実行せずにシグナルをselfから切り離す。
  # signal_connectは、ブロックが例外を投げるとSegmentation Faultするが、このメソッドを使えば正常にクラッシュする。
  # ==== Args
  # [signal] イベント名か、イベントとブロックの連想配列
  #   Symbol|String :: イベントの名前
  #   Hash :: キーにイベント名、値に呼び出すブロックを持つHash
  # [*related] GLib::Object ブロック実行時、これらのうちどれか一つでも削除されていたらブロックを実行しない
  # [&proc] signalがイベントの名前の場合、イベントが発生したらこのブロックが呼ばれる
  # ==== Return
  # signal_connectと同じ
  def safety_signal_connect(signal, *related, &proc)
    case signal
    when Hash
      signal.each{ |name, callback|
        safety_signal_connect(name, *related, &callback) }
    when String, Symbol
      related.each{ |gobj|
        raise ArgumentError.new(gobj.to_s) unless gobj.is_a?(GLib::Object) }
      if related
        sid = signal_connect(signal) do |*args|
          begin
            if not(destroyed?)
              if (related.any?(&:destroyed?))
                signal_handler_disconnect(sid)
              else
                proc.call(*args)
              end
            end
          rescue Exception => err
            Gtk.exception = err
          end
        end
      else
        signal_connect(signal) do |*args|
          if !destroyed?
            proc.call(*args)
          end
        rescue Exception => err
          Gtk.exception = err
        end
      end
    else
      raise ArgumentError, "First argument should Hash, String, or Symbol." end end
  alias ssc safety_signal_connect

  # safety_signal_connect を、イベントが発生した最初の一度だけ呼ぶ
  def safety_signal_connect_atonce(signal, *related, &proc)
    called = false
    sid = ssc(signal, *related) { |*args|
      unless called
        called = true
        signal_handler_disconnect(sid)
        proc.call(*args) end }
    sid end
  alias ssc_atonce safety_signal_connect_atonce

  private
  def __track(&proc)
    type_strict proc => :call
    trace = caller(3)
    lambda{ |*args|
      begin
        proc.call(*args)
      rescue Exception => e
        now = caller.size + 1     # proc.callのぶんスタックが１つ多い
        #$@ = e.backtrace[0, e.backtrace.size - now] + trace
        Gtk.exception = e
        into_debug_mode(e, proc.binding)
        raise e end
    }
  end

end

class Gdk::Rectangle
  def to_s
    "#<Gtk::Rectangle x=#{x} y=#{y} width=#{width} height=#{height}>"
  end
end

module Gtk
  NO_ACTION = '(割り当てなし)'.freeze
  PRESS_WITH_CONTROL = 'Control + '.freeze
  PRESS_WITH_SHIFT = 'Shift + '.freeze
  PRESS_WITH_ALT = 'Alt + '.freeze
  PRESS_WITH_SUPER = 'Super + '.freeze
  PRESS_WITH_HYPER = 'Hyper + '.freeze
  KonamiCache = File.expand_path(File.join(Environment::CACHE, 'core', 'konami.png'))

  class << self
    attr_accessor :exception, :konami
    attr_reader :konami_image
  end

  self.konami = false

  def self.konami_load
    return if @konami
    if FileTest.exist? KonamiCache
      @konami_image = GdkPixbuf::Pixbuf.new(file: KonamiCache, width: 41, height: 52)
      @konami = true
    else
      Thread.new do
        tmpfile = File.join(Environment::TMPDIR, '600eur')
        URI('https://mikutter.hachune.net/img/konami.png').open('rb') do |konami|
          File.open(tmpfile, 'wb'){ |cache| IO.copy_stream konami, cache }
        end
        FileUtils.mkdir_p(File.dirname(KonamiCache))
        FileUtils.mv(tmpfile, KonamiCache)
        @konami_image = GdkPixbuf::Pixbuf.new(file: KonamiCache, width: 41, height: 52)
        @konami = true
      rescue => exception
        error exception
      end
    end
  end

  def self.keyname(key)
    type_strict key => Array
    return NO_ACTION if key.empty? or key[0] == 0 or not key.all?

    r = ""
    r << PRESS_WITH_CONTROL if (key[1] & :control_mask) != 0
    r << PRESS_WITH_SHIFT if (key[1] & :shift_mask) != 0
    r << PRESS_WITH_ALT if (key[1] & :mod1_mask) != 0
    r << PRESS_WITH_SUPER if (key[1] & :super_mask) != 0
    r << PRESS_WITH_HYPER if (key[1] & :hyper_mask) != 0
    return r + Gdk::Keyval.to_name(key[0]) end

  def self.buttonname(key)
    type_strict key => Array
    type, button, state = key
    return NO_ACTION if key.empty? or type == 0 or not key.all?
    r = ""
    r << PRESS_WITH_CONTROL if (state & Gdk::ModifierType::CONTROL_MASK) != 0
    r << PRESS_WITH_SHIFT if (state & Gdk::ModifierType::SHIFT_MASK) != 0
    r << PRESS_WITH_ALT if (state & Gdk::ModifierType::MOD1_MASK) != 0
    r << PRESS_WITH_SUPER if (state & Gdk::ModifierType::SUPER_MASK) != 0
    r << PRESS_WITH_HYPER if (state & Gdk::ModifierType::HYPER_MASK) != 0
    r << "Button #{button} "
    case type
    when Gdk::EventType::BUTTON_PRESS
      r << 'Click'.freeze
    when Gdk::EventType::BUTTON2_PRESS
      r << 'Double Click'.freeze
    when Gdk::EventType::BUTTON3_PRESS
      r << 'Triple Click'.freeze
    else
      return NO_ACTION end
    return r end

end

=begin rdoc
= Gtk::Lock Ruby::Gnome2の排他制御
メインスレッド以外でロックしようとするとエラーを発生させる。
Gtkを使うところで、メインスレッドではない疑いがある箇所は必ずGtk::Lockを使う。
=end
class Gtk::Lock
  # ブロック実行前に _lock_ し、実行後に _unlock_ する。
  # ブロックの実行結果を返す。
  def self.synchronize
    begin
      lock
      yield
    ensure
      unlock
    end
  end

  # メインスレッド以外でこの関数を呼ぶと例外を発生させる。
  def self.lock
    raise 'Gtk lock can mainthread only' if Thread.main != Thread.current
  end

  def self.unlock
  end
end

# TODO: gtk3: remove it
class Gtk::Widget
  extend Gem::Deprecate

  # Kotlinのapply風のメソッド
  # https://kotlinlang.org/docs/reference/scope-functions.html#apply
  def apply(&p)
    instance_eval(&p)
    self
  end

  # ウィジェットを上寄せで配置する
  def top
    Gtk::Alignment.new(0.0, 0, 0, 0).add(self)
  end
  deprecate :top, :valign=, 2018, 9

  # ウィジェットを横方向に中央寄せで配置する
  def center
    Gtk::Alignment.new(0.5, 0, 0, 0).add(self)
  end
  deprecate :center, :halign=, 2018, 9

  # ウィジェットを左寄せで配置する
  def left
    Gtk::Alignment.new(0, 0, 0, 0).add(self)
  end
  deprecate :left, :halign=, 2018, 9

  # ウィジェットを右寄せで配置する
  def right
    Gtk::Alignment.new(1.0, 0, 0, 0).add(self)
  end
  deprecate :right, :halign=, 2018, 9

  # ウィジェットにツールチップ _text_ をつける
  def tooltip(text)
    self.tooltip_text = text
    self end
  deprecate :tooltip, :tooltip_text=, 2018, 9

end

class Gtk::Box
  extend Gem::Deprecate

  # _widget_ を詰めて配置する。closeupで配置されたウィジェットは無理に親の幅に合わせられることがない。
  # pack_start(_widget_, expand: false)と等価。
  def closeup(widget)
    pack_start(widget, expand: false)
  end
  deprecate :closeup, :none, 2018, 9
end

class Gtk::TextBuffer < GLib::Object
  # _idx_ 文字目を表すイテレータと、そこから _size_ 文字後ろを表すイテレータの2要素からなる配列を返す。
  def get_range(idx, size)
    [self.get_iter_at(offset: idx), self.get_iter_at(offset: idx + size)]
  end
end

class Gtk::Clipboard
  # 文字列 _t_ をクリップボードにコピーする
  def self.copy(t)
    Gtk::Clipboard.get(Gdk::Atom.intern('CLIPBOARD', true)).text = t
  end

  # クリップボードから文字列を取得する
  def self.paste
    Gtk::Clipboard.get(Gdk::Atom.intern('CLIPBOARD', true)).wait_for_text
  end
end

class Gtk::Dialog
  # メッセージダイアログを表示する。
  def self.alert(message)
    Gtk::Lock.synchronize{
      dialog = Gtk::MessageDialog.new(nil,
                                      Gtk::Dialog::DESTROY_WITH_PARENT,
                                      Gtk::MessageDialog::QUESTION,
                                      Gtk::MessageDialog::BUTTONS_CLOSE,
                                      message)
      dialog.run
      dialog.destroy
    }
  end

  # Yes,Noの二択の質問を表示する。
  # YESボタンが押されたらtrue、それ以外が押されたらfalseを返す
  def self.confirm(message)
    Gtk::Lock.synchronize{
      dialog = Gtk::MessageDialog.new(parent: nil,
                                      flags: Gtk::DialogFlags::DESTROY_WITH_PARENT,
                                      type: Gtk::MessageType::QUESTION,
                                      buttons: Gtk::ButtonsType::YES_NO,
                                      message: message)
      res = dialog.run
      dialog.destroy
      res == Gtk::ResponseType::YES
    }
  end
end

class Gtk::Notebook
  # ラベルウィジェットが何番目のタブかを返す
  # ==== Args
  # [label] ラベルウィジェット
  # ==== Return
  # インデックス(見つからない場合nil)
  def get_tab_pos_by_tab(label)
    n_pages.times do |page_num|
      if(get_tab_label(get_nth_page(page_num)) == label)
        return page_num
      end
    end
    nil
  end

  # ページをindex0から順に走査し、 _&block_ を呼び出す。
  # ブロックを渡さない場合、Enumeratorを返す。
  def each_pages(&block)
    if block
      n_pages.times.map(&method(:get_nth_page)).each(&block)
    else
      to_enum(:each_pages)
    end
  end
end

class Cairo::Context
  class << self
    def dummy
      @dummy ||= Cairo::Context.new(Cairo::ImageSurface.new(Cairo::Format::ARGB32, 1, 1))
    end
  end
end

class Pango::FontDescription
  # 絵文字を描画する時の一辺の大きさを返す
  # ==== Args
  # [font] font description
  # ==== Return
  # [Integer] 高さ(px)
  def forecast_font_size
    Pango::FontDescription.forecast_font_size(self)
  end

  @forecast_font_description = Hash.new
  def self.forecast_font_size(fd)
    @forecast_font_description[fd.hash] ||=
      PangoCairo::FontMap
        .default
        .create_context
        .then(&Pango::Layout.method(:new))
        .then do |layout|
      layout.font_description = fd
      layout.text = '.'
      layout.pixel_size[1]
    end
  end
end

class Gtk::ListStore
  def model
    self end
end

module Gtk
  # _url_ を設定されているブラウザで開く
  class << self
    def openurl(url)
      Plugin.call(:open, url)
    end
  end
end

module Gdk
  class << self
    def scale(val)
      case UserConfig[:ui_scale]
      when :auto
        @resolution ||= Gdk::Visual.system.screen.resolution
        @resolution < 0 and @resolution = 96
        val * @resolution / 96
      else
        val * UserConfig[:ui_scale]
      end.to_i
    end
  end
end

class Gtk::Style
  CSS_PSEUDO_CLASS_BY_STATE_TYPE = {
    Gtk::StateType::NORMAL => '',
    Gtk::StateType::ACTIVE => ':active',
    Gtk::StateType::SELECTED => ':focus',
    Gtk::StateType::PRELIGHT => ':hover',
    Gtk::StateType::INSENSITIVE => ':disabled'
  }

  # NOTE: gtk2向けコードとの後方互換のために用意したが使われないことを祈る
  def to_style_provider
    Gtk::CssProvider.new.tap do |provider|
      styles = {}
      CSS_PSEUDO_CLASS_BY_STATE_TYPE.each do |type, pseudo_class|
        color = bg[type]
        if color
          selector = "*#{pseudo_class}"
          styles[selector] ||= ''
          styles[selector] += "background-color: rgb(#{color[0] / 256}, #{color[1] / 256}, #{color[2] / 256});"
        end
      end
      css = styles.map { |selector, style| "#{selector} { #{style} }" }.join(' ')
      provider.load_from_data(css)
    end
  rescue NotImplementedError => e
    # NotImplementedErrorが発生し、内容に正しくアクセスできない可能性がある
    error e
    Gtk::CssProvider.new
  end
end

unless Kernel.const_defined?(:GdkPixbuf)
  module GdkPixbuf
    Pixbuf = Gdk::Pixbuf
    PixbufLoader = Gdk::PixbufLoader
    PixbufError = Gdk::PixbufError
  end
end

module MUI
  Skin = ::Skin

  module ColorConverter
    refine NilClass do
      def rgba
        Gdk::RGBA.new
      end
    end

    refine Array do
      def rgba
        case first
        when Integer
          # Gdk::Color style
          Gdk::RGBA.new(*map { |i| i.to_f / 65535 })
        when Float
          # Gdk::RGBA style
          Gdk::RGBA.new(*self)
        else
          raise TypeError, 'receiver values are not compatible'
        end
      end
    end

    refine Gdk::RGBA do
      def to_color_array
        to_a[0..2].map { |f| f * 65535 }.map(&:to_i)
      end
    end
  end
end
