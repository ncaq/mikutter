# -*- coding: utf-8 -*-
require 'mui/gtk_extension'
require 'mui/gtk_contextmenu'
require 'plugin'
require 'miku/miku'

require 'gtk3'
require 'uri'

class Gtk::IntelligentTextview < Gtk::TextView
  extend Gem::Deprecate

  attr_accessor :fonts
  attr_writer :style_generator
  alias :get_background= :style_generator=
  deprecate :get_background=, "style_generator=", 2017, 02

  @@linkrule = MIKU::Cons.list([URI.regexp(['http','https']),
                                lambda{ |u, clicked| self.openurl(u) },
                                lambda{ |u, clicked|
                                  Gtk::ContextMenu.new(['リンクのURLをコピー', ret_nth, lambda{ |opt, w| Gtk::Clipboard.copy(u) }],
                                                       ['開く', ret_nth, lambda{ |opt, w| self.openurl(u) }]).
                                  popup(clicked, true)}])
  @@widgetrule = []

  def self.addlinkrule(reg, leftclick, rightclick=nil)
    @@linkrule = MIKU::Cons.new([reg, leftclick, rightclick].freeze, @@linkrule).freeze end

  def self.addwidgetrule(reg, widget = nil, &block)
    @@widgetrule = @@widgetrule.unshift([reg, (widget || block)]) end

  # URLを開く
  def self.openurl(url)
    # gen_openurl_proc(url).call
    Gtk::TimeLine.openurl(url) # FIXME
    false end

  def initialize(msg = nil, default_fonts = {}, *rest, style: nil)
    super(*rest)
    @fonts = default_fonts
    @style_generator = style
    self.editable = false
    self.cursor_visible = false
    self.wrap_mode = :char
    gen_body(msg) if msg
  end

  # このウィジェットの背景色を返す
  # ==== Return
  # Gtk::Style
  def style_generator
    if @style_generator.respond_to? :to_proc
      @style_generator.to_proc.call
    elsif @style_generator
      @style_generator
    else
      # FIXME: gtk3, find alternative method
      # parent.style.bg(Gtk::STATE_NORMAL)
    end
  end
  alias :get_background :style_generator
  deprecate :get_background, "style_generator", 2017, 02

  # TODO プライベートにする
  def set_cursor(textview, cursor)
    # FIXME: gtk3, find alternative method
    # textview.get_window(Gtk::TextView::WINDOW_TEXT).set_cursor(Gdk::Cursor.new(cursor))
  end

  def bg_modifier(color = style_generator)
    if color.is_a? Gtk::Style
      warn 'Gtk::IntelligentTextview#bg_modifier(Gtk::Style) is deprecated.'
      color = color.to_style_provider
    end
    if color.is_a? Gtk::StyleProvider
      style_context.add_provider(color, Gtk::StyleProvider::PRIORITY_APPLICATION)
    # FIXME: gtk3, find alternative
    # elsif get_window(Gtk::TextView::WINDOW_TEXT).respond_to?(:background=)
    #   get_window(Gtk::TextView::WINDOW_TEXT).background = color
    end
    queue_draw
  end

  # 新しいテキスト _msg_ に内容を差し替える。
  # ==== Args
  # [msg] 表示する文字列
  # ==== Return
  # self
  def rewind(msg)
    set_buffer(Gtk::TextBuffer.new)
    gen_body(msg)
  end

  private

  def fonts2tags(fonts)
    tags = Hash.new
    tags['font'] = UserConfig[fonts['font']] if fonts.has_key?('font')
    if fonts.has_key?('foreground')
      tags['foreground_gdk'] = Gdk::Color.new(*UserConfig[fonts['foreground']]) end
    tags
  end

  def gen_body(msg, fonts={})
    tag_shell = buffer.create_tag('shell', fonts2tags(fonts))
    case msg
    when String
      type_strict fonts => Hash
      tags = fonts2tags(fonts)
      buffer.insert(buffer.start_iter, msg, 'shell')
      apply_links
      apply_inner_widget
    when Enumerable # score
      pos = buffer.end_iter
      msg.each_with_index do |note, index|
        case
        when UserConfig[:miraclepainter_expand_custom_emoji] && note.respond_to?(:inline_photo)
          photo = note.inline_photo
          font_size = tag_shell.font_desc.forecast_font_size
          start = pos.offset
          pixbuf = photo.load_pixbuf(width: font_size, height: font_size) do |loaded_pixbuf|
            unless buffer.destroyed?
              insertion_start = buffer.get_iter_at_offset(start)
              buffer.delete(insertion_start, buffer.get_iter_at_offset(start+1))
              buffer.insert(insertion_start, loaded_pixbuf)
            end
          end
          buffer.insert(pos, pixbuf)
        when clickable?(note)
          tagname = "tag#{index}"
          create_tag_ifnecessary(tagname, buffer,
                                 ->(_tagname, _textview){
                                   Plugin.call(:open, note)
                                 }, nil)
          start = pos.offset
          buffer.insert(pos, note.description)
          buffer.apply_tag(tagname, buffer.get_iter_at_offset(start), pos)
        else
          buffer.insert(pos, note.description, 'shell')
        end
      end
    end
    set_events(tag_shell)
    self
  end

  def set_events(tag_shell)
    self.signal_connect('realize'){
      self.parent.signal_connect('style-set'){ bg_modifier } }
    self.signal_connect('realize'){ bg_modifier }
    self.signal_connect('visibility-notify-event'){
      if fonts['font'] and tag_shell.font != UserConfig[fonts['font']]
        tag_shell.font = UserConfig[fonts['font']] end
      if fonts['foreground'] and tag_shell.foreground_gdk.to_s != UserConfig[fonts['foreground']]
        tag_shell.foreground_gdk = Gdk::Color.new(*UserConfig[fonts['foreground']]) end
      false }
    self.signal_connect('event'){
      set_cursor(self, Gdk::CursorType::XTERM)
      false }
  end

  def create_tag_ifnecessary(tagname, buffer, leftclick, rightclick)
    tag = buffer.create_tag(tagname, "underline" => Pango::Underline::SINGLE)
    tag.signal_connect('event'){ |this, textview, event, iter|
      result = false
      if(event.is_a?(Gdk::EventButton)) and
          (event.event_type == Gdk::Event::BUTTON_RELEASE) and
          not(textview.buffer.selection_bounds[2])
        if (event.button == 1 and leftclick)
          leftclick.call(tagname, textview)
        elsif(event.button == 3 and rightclick)
          rightclick.call(tagname, textview)
          result = true end
      elsif(event.is_a?(Gdk::EventMotion))
        set_cursor(textview, Gdk::Cursor::HAND2)
      end
      result }
    tag end

  def apply_links
    @@linkrule.each{ |param|
      reg, left, right = param
      buffer.text.scan(reg) {
        match = Regexp.last_match
        index = buffer.text[0, match.begin(0)].size
        body = match.to_s.freeze
        create_tag_ifnecessary(body, buffer, left, right) if not buffer.tag_table.lookup(body)
        range = buffer.get_range(index, body.size)
        buffer.apply_tag(body, *range)
      } } end

  def apply_inner_widget
    offset = 0
    @@widgetrule.each{ |param|
      reg, widget_generator = param
      buffer.text.scan(reg) { |match|
        match = Regexp.last_match
        index = [buffer.text.size, match.begin(0)].min
        body = match.to_s.freeze
        range = buffer.get_range(index, body.size + offset)
        widget = widget_generator.call(body)
        if widget
          self.add_child_at_anchor(widget, buffer.create_child_anchor(range[1]))
          offset += 1 end } } end

  def clickable?(model)
    has_model_intent = Plugin.collect(:intent_select_by_model_slug, model.class.slug, Pluggaloid::COLLECT).first
    return true if has_model_intent
    Plugin.collect(:model_of_uri, model.uri).any? do |model_slug|
      Plugin.collect(:intent_select_by_model_slug, model_slug, Pluggaloid::COLLECT).first
    end
  end
end
