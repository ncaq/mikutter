# -*- coding: utf-8 -*-
require 'mui/cairo_icon_over_button'
require 'mui/cairo_textselector'
require 'mui/cairo_sub_parts_helper'
require 'mui/cairo_replyviewer'
require 'mui/cairo_sub_parts_favorite'
require 'mui/cairo_sub_parts_share'
require 'mui/cairo_sub_parts_quote'
require 'mui/cairo_markup_generator'
require 'mui/cairo_special_edge'
require 'mui/gtk_photo_pixbuf'

# Diva::Modelを表示するためのGtk::ListBoxRow。
# 名前は言いたかっただけ。クラス名まで全てはつね色に染めて♪
class Plugin::Gtk3::MiraclePainter < Gtk::ListBoxRow
  # * カスタムwidgetの実装
  #   https://developer.gnome.org/gtkmm-tutorial/stable/sec-custom-widgets.html.en
  # * height-for-widthの実装
  #   https://developer.gnome.org/gtk3/stable/GtkWidget.html#GtkWidget.description

  class Rect
    extend Memoist
    attr_reader :x, :y, :width, :height

    def initialize(x, y, width, height)
      @x, @y, @width, @height = x, y, width, height
    end

    def point_in?(x, y)
      left <= x and x <= right and top <= y and y <= bottom
    end

    def bottom
      y + height end

    def right
      x + width end

    alias :left :x
    alias :top :y
  end

  ICON_SIZE = [48, 48].freeze # [width, height]
  MARGIN = 2 # margin for icon, etc
  SPACING = 2 # spacing between mainparts and subparts
  DEPTH = Gdk::Visual.system.depth # color depth
  VERBOSE = false # for debug

  extend Gem::Deprecate

  type_register

  signal_new :clicked, GLib::Signal::RUN_FIRST | GLib::Signal::ACTION, nil, nil, Gdk::EventButton
  
  signal_new :click, GLib::Signal::RUN_FIRST | GLib::Signal::ACTION, nil, nil, Gdk::EventButton, Integer, Integer # 互換性
  signal_new :expose_event, GLib::Signal::RUN_FIRST, nil, nil # 互換性

  include Gdk::IconOverButton
  include Gdk::TextSelector
  include Gdk::SubPartsHelper
  include Gdk::MarkupGenerator

  WHITE = [1.0, 1.0, 1.0].freeze
  BLACK = [0.0, 0.0, 0.0].freeze
  NUMERONYM_MATCHER = /[a-zA-Z]{4,}/.freeze
  NUMERONYM_CONVERTER = ->(r) { "#{r[0]}#{r.size-2}#{r[-1]}" }

  attr_reader :model
  alias message model
  # TODO: gtk3 deprecate :message
  # deprecate :message, :model, 2019, 10

  # TODO: gtk3 adjust size
  WIDTH_MIN = 100 # minimum width
  WIDTH_NAT = 250 # natural width

  # :nodoc:
  def score
    @score ||= Plugin[:gtk3].score_of(model)
  end

  def initialize(model)
    super()

    @model = model
    @mouse_in_row = false

    # This widget create _Gdk::Window_ itself on _realize_.
    self.has_window = true
    self.redraw_on_allocate = true
    style_context.add_class 'miraclepainter'
  end

  # override virtual function Gtk::Widget.get_request_mode
  def virtual_do_get_request_mode
    notice 'MiraclePainter#get_request_mode' if VERBOSE

    Gtk::SizeRequestMode::HEIGHT_FOR_WIDTH
  end

  # override virtual function Gtk::Widget.get_preferred_width
  def virtual_do_get_preferred_width
    notice 'MiraclePainter#get_preferred_width' if VERBOSE

    [WIDTH_MIN, WIDTH_NAT]
  end

  # override virtual function Gtk::Widget.get_preferred_height_for_width
  def virtual_do_get_preferred_height_for_width(width)
    notice "MiraclePainter#get_preferred_height_for_width(width=#{width})" if VERBOSE

    @width = width
    height = mainpart_height + SPACING + subparts_height
    [height, height] # minimum, natural
  rescue Exception => exc
    Gtk.exception = exc
    [0, 0]
  end

  # connect signal Gtk::Widget*parent_set
  def signal_do_parent_set(prev_parent)
    notice "#{self}*parent_set(prev_parent=#{prev_parent.inspect}) " \
      "parent=#{parent.inspect}" if VERBOSE

    @width = allocated_width
  end

  # connect signal Gtk::Widget*size_allocate
  # リサイズ時に呼ばれる
  # signalの発行順序: size_allocate > realize > draw
  def signal_do_size_allocate(rect)
    notice "#{self}*size_allocate(rect=#{rect})" if VERBOSE

    self.allocation = rect
    x, y, w, h = rect.x, rect.y, rect.width, rect.height
    if realized?
      window.move_resize(x, y, w, h)
    end
    @width = w
  end

  # connect signal Gtk::Widget*realize
  def signal_do_realize
    notice "#{self}*realize" if VERBOSE

    x, y, w, h = allocation.x, allocation.y, allocation.width, allocation.height
    attr = (Gdk::WindowAttr.new w, h, :input_output, :child).tap do |attr|
      attr.x = x
      attr.y = y
      attr.visual = visual
      em = Gdk::EventMask
      attr.event_mask = em::BUTTON_PRESS_MASK |
        em::BUTTON_RELEASE_MASK |
        em::POINTER_MOTION_MASK |
        em::ENTER_NOTIFY_MASK |
        em::LEAVE_NOTIFY_MASK |
        em::TOUCH_MASK
    end

    wat = Gdk::WindowAttributesType
    mask = wat::X | wat::Y | wat::VISUAL

    self.window = Gdk::Window.new parent_window, attr, mask
    register_window window

    self.realized = true
  end

  # connect signal Gtk::Widget*unrealize
  def signal_do_unrealize
    notice "#{self}*unrealize" if VERBOSE

    unregister_window window
    window.destroy
    self.realized = false
  end

  # connect signal Gtk::Widget*map
  def singla_do_map
    super

    window.show
  end

  # connect signal Gtk::Widget*unmap
  def signal_do_unmap
    super

    window.hide
  end

  # connect signal Gtk::Widget*draw
  def signal_do_draw(context)
    # context => Cairo::Context
    notice "#{self}*draw(context)" if VERBOSE

    x, y, w, h = allocation.x, allocation.y, allocation.width, allocation.height

    Gtk.render_frame style_context, context, x, y, w, h
    Gtk.render_background style_context, context, x, y, w, h

    render_to_context(context)
    true # stop propagation
  rescue Exception => err
    Gtk.exception = err
    true # stop propagation
  end

  # connect signal Gtk::Widget*clicked
  def signal_do_clicked(ev)
    notice "#{self}*clicked(ev=#{ev.inspect})" if VERBOSE

    x, y = ev.x, ev.y
    case ev.button
    when 1
      iob_clicked(x, y)
      if not textselector_range
        index = main_pos_to_index(x, y)
        if index
          clicked_note = score.find{|note|
            index -= note.description.size
            index <= 0
          }
          Plugin.call(:open, clicked_note) if clickable?(clicked_note)
        end
      end
    end
  end

  # 互換性
  def signal_do_click(ev, cell_x, cell_y); end

  def signal_do_button_press_event(ev)
    notice "#{self}*button_press_event(ev=#{ev.inspect})" if VERBOSE

    if ev.triggers_context_menu
      popup_menu ev
      return true
    end

    if ev.button == 1
      textselector_press(*main_pos_to_index_forclick(ev.x, ev.y)[1..2])
    end
    false # propagate event
  end

  def signal_do_button_release_event(ev)
    notice "#{self}*button_release_event(ev=#{ev.inspect})" if VERBOSE

    x, y = ev.x, ev.y
    ev.button == 1 \
      and textselector_release(*main_pos_to_index_forclick(x, y)[1..2])
    if @mouse_in_row || ev.event_type == Gdk::EventType::TOUCH_END
      signal_emit :clicked, ev
      signal_emit :click, ev, x, y # 互換性
    end
    false # propagate event
  end

  def signal_do_motion_notify_event(ev)
    x, y = ev.x, ev.y
    point_moved_main_icon(x, y)
    textselector_select(*main_pos_to_index_forclick(x, y)[1..2])

    # change cursor shape
    window.cursor = Gdk::Cursor.new(cursor_name_of(x, y))
    false # propagate event
  end

  def signal_do_enter_notify_event(_)
    @mouse_in_row = true
    false # propagate event
  end

  def signal_do_leave_notify_event(_)
    @mouse_in_row = false
    iob_main_leave
    textselector_release
    # restore cursor shape
    window.cursor = nil
    false # propagate event
  end

  def signal_do_focus_in_event(event)
    get_ancestor(Plugin::Gtk3::Timeline).active
  end

  def signal_do_key_press_event(event)
    timeline = get_ancestor(Plugin::Gtk3::Timeline)
    timeline.keypress(Gtk.keyname [event.keyval, event.state])
  end

  def signal_do_state_flags_changed(prev_flags)
    notice "#{self}*state_flags_changed(prev_flags=#{prev_flags.inspect}) " \
      "state_flags=#{state_flags.inspect}" if VERBOSE

    (state_flags & Gtk::StateFlags::SELECTED).zero? and textselector_unselect
  end

  # for keybindings (Shift-F10 or Menu)
  # see https://developer.gnome.org/gtk3/stable/gtk-migrating-checklist.html#checklist-popup-menu
  def signal_do_popup_menu
    popup_menu(nil)
    true
  end

  def iob_icon_pixbuf
    [ ["reply.png".freeze, message.user.verified? ? "verified.png" : "etc.png"],
      [if message.user.protected? then "protected.png".freeze else "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : "fav.png".freeze] ] end

  def iob_icon_pixbuf_off
    world, = Plugin.filtering(:world_current, nil)
    [ [(UserConfig[:show_replied_icon] and message.mentioned_by_me? and "reply.png".freeze),
       UserConfig[:show_verified_icon] && message.user.verified? && "verified.png"],
      [ if UserConfig[:show_protected_icon] and message.user.protected?
          "protected.png".freeze
        elsif Plugin[:miracle_painter].shared?(message, world)
          "retweet.png".freeze end,
       message.favorite? ? "unfav.png".freeze : nil]
    ]
  end

  def iob_reply_clicked
    get_ancestor(Plugin::Gtk3::Timeline).imaginary.create_reply_postbox(message)
  end

  def iob_retweet_clicked
    world, = Plugin.filtering(:world_current, nil)
    if Plugin[:miracle_painter].shared?(message, world)
      retweet = message.retweeted_statuses.find(&:from_me?)
      retweet.destroy if retweet
    else
      Plugin[:miracle_painter].share(message, world)
    end
  end

  def iob_fav_clicked
    message.favorite(!message.favorite?)
  end

  def iob_etc_clicked
  end

  # つぶやきの左上座標から、クリックされた文字のインデックスを返す
  def main_pos_to_index(x, y)
    x -= main_text_rect.x
    y -= main_text_rect.y
    inside, byte, trailing = *main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    main_message.text.get_index_from_byte(byte) if inside end

  def main_pos_to_index_forclick(x, y)
    x -= main_text_rect.x
    y -= main_text_rect.y
    result = main_message.xy_to_index(x * Pango::SCALE, y * Pango::SCALE)
    result[1] = main_message.text.get_index_from_byte(result[1])
    return *result end

  @@font_description = Hash.new{|h,k| h[k] = {} } # {scale => {font => FontDescription}}
  def font_description(font)
    @@font_description[Gdk.scale(0xffff)][font] ||=
      Pango::FontDescription.new(font).tap{|fd| fd.size = Gdk.scale(fd.size) }
  end

  def mainpart_height
    [
      forecast_main_message_height + forecast_header_left_height,
      Gdk.scale(ICON_SIZE[1]),
    ].max + MARGIN
  end

  def forecast_main_message_height
    # TODO: Pango::Layoutに描画して正しい高さを予想する
    @main_message_height || 0#main_message.pixel_size[1]
  end

  def forecast_header_left_height
    # TODO: Pango::Layoutに描画して正しい高さを予想する
    @header_left_height || 0#header_left.pixel_size[1]
  end

  # 互換性
  def reset_height
    queue_resize
  end
  deprecate :reset_height, :queue_resize, 2020, 7

  # 互換性
  def on_modify
    queue_resize
  end
  deprecate :on_modify, :queue_resize, 2020, 7

  def inspect
    "MP(#{model.description[0, 5].gsub("\n", ' ').inspect})"
  end
  alias to_s inspect

private

  def popup_menu(event)
    get_ancestor(Plugin::Gtk3::Timeline).popup_menu(event)
  end

  def main_icon_rect
    @main_icon_rect ||= Rect.new(MARGIN, MARGIN, *ICON_SIZE.map(&Gdk.method(:scale)))
  end

  # 本文(model#description)
  def main_text_rect
    Rect.new(
      Gdk.scale(ICON_SIZE[0]) + 2 * MARGIN,
      header_text_rect.height,
      text_width,
      0
    )
  end

  def header_text_rect
    Rect.new(
      Gdk.scale(ICON_SIZE[0]) + 2 * MARGIN,
      MARGIN,
      text_width,
      forecast_header_left_height
    )
  end

  def text_width
    @width - Gdk.scale(ICON_SIZE[0]) - 4 * MARGIN
  end

  # 本文のための Pango::Layout のインスタンスを返す
  def main_message(context = nil)
    layout = (context || self).create_pango_layout
    font = Plugin.filtering(:message_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.text = plain_description
    layout.width = main_text_rect.width * Pango::SCALE
    layout.attributes = textselector_attr_list(
      description_attr_list(emoji_height: layout.pixel_size[1])
    )
    layout.wrap = Pango::WrapMode::CHAR
    if context
      context.set_source_rgb(*htmlcolor2gdk(Plugin.filtering(:message_font_color, message, nil).last || BLACK))

      layout.context&.set_shape_renderer do |c, shape, _|
        next layout unless photo = shape.data
        width, height = shape.ink_rect.width/Pango::SCALE, shape.ink_rect.height/Pango::SCALE
        pixbuf = photo.load_pixbuf(width: width, height: height) do
          queue_draw
        end
        x = layout.index_to_pos(shape.start_index).x / Pango::SCALE
        y = layout.index_to_pos(shape.start_index).y / Pango::SCALE
        c.translate(x, y)
        c.set_source_pixbuf(pixbuf)
        c.rectangle(0, 0, width, height)
        c.fill
      end
      # 実際に描画してみた結果、高さが最後の予測と異なっている場合
      actual_height = layout.pixel_size[1]
      unless @main_message_height == actual_height
        @main_message_height = actual_height
        queue_resize
      end
    end
    layout
  end

  # ヘッダ（左）のための Pango::Layout のインスタンスを返す
  def header_left(context = nil)
    attr_list, text = header_left_markup
    font = Plugin.filtering(:message_header_left_font, message, nil).last
    context&.set_source_rgb(*htmlcolor2gdk(Plugin.filtering(:message_header_left_font_color, message, nil).last || BLACK))
    (context || self).create_pango_layout.tap do |layout|
      layout.attributes = attr_list
      layout.font_description = font_description(font) if font
      layout.text = text
      # 実際に描画してみた結果、高さが最後の予測と異なっている場合
      actual_height = layout.pixel_size[1]
      if context && @header_left_height != actual_height
        @header_left_height = actual_height
        queue_resize
      end
    end
  end

  def header_left_markup
    user = message.user
    if user.respond_to?(:idname)
      Pango.parse_markup("<b>#{Pango.escape(rinsuki_abbr(user))}</b> #{Pango.escape(user.name || '')}")
    else
      Pango.parse_markup(Pango.escape(user.name || ''))
    end
  end

  def rinsuki_abbr(user)
    return user.idname unless UserConfig[:idname_abbr]
    prefix, domain = user.idname.split('@', 2)
    if domain
      "#{prefix}@#{domain.gsub(NUMERONYM_MATCHER, &NUMERONYM_CONVERTER)}"
    else
      user.idname
    end
  end

  # ヘッダ（右）のための Pango::Layout のインスタンスを返す
  def header_right(context)
    hms = timestamp_label
    attr_list, text = Pango.parse_markup(hms)
    layout = context.create_pango_layout
    layout.attributes = attr_list
    font = Plugin.filtering(:message_header_right_font, message, nil).last
    layout.font_description = font_description(font) if font
    layout.text = text
    layout.alignment = Pango::Alignment::RIGHT
    layout end

  def timestamp_label
    now = Time.now
    if message.created.year == now.year && message.created.month == now.month && message.created.day == now.day
      Pango.escape(message.created.strftime('%H:%M:%S'))
    else
      Pango.escape(message.created.strftime('%Y/%m/%d %H:%M:%S'))
    end
  end

  # アイコンのpixbufを返す
  def main_icon
    w, h = ICON_SIZE
    @main_icon ||= model.user.icon.load_pixbuf(width: Gdk.scale(w), height: Gdk.scale(h)) do |pb|
      @main_icon = pb
      queue_draw
    end
  end

  # 背景色を返す
  def get_backgroundcolor
    color = Plugin.filtering(
      selected? ? :message_selected_bg_color : :message_bg_color,
      model, nil
    ).last
    htmlcolor2gdk(color || WHITE)
  end

  # GTK2のGtk::ColorとGTK3のGdk::RGBAをRGBの_Float_値に変換する
  def htmlcolor2gdk(color)
    r, g, b = color
    [r.fdiv(65536), g.fdiv(65536), b.fdiv(65536)].freeze
  end

  # Graphic Context にパーツを描画
  def render_to_context(context)
    render_background(context)
    render_main_icon(context)
    render_main_text(context)
    render_parts(context)
  end

  def render_background(context)
    context.save do
      context.set_source_rgb(*get_backgroundcolor)
      context.rectangle(0, 0, allocation.width, allocation.height)
      context.fill
      if Gtk.konami
        context.save do
          context.translate(width - 48, height - 54)
          context.set_source_pixbuf(Gtk.konami_image)
          context.paint end end end end

  def render_main_icon(context)
    case Plugin.filtering(:main_icon_form, :square)[0]
    when :aspectframe
      render_main_icon_aspectframe(context)
    else
      render_main_icon_square(context)
    end
  end

  def render_main_icon_square(context)
    context.save{
      context.translate(main_icon_rect.x, main_icon_rect.y)
      context.set_source_pixbuf(main_icon)
      context.paint
    }
    if not (message.system?)
      render_icon_over_button(context) end
  end

  def render_main_icon_aspectframe(context)
    context.save do
      context.save do
        context.translate(main_icon_rect.x, main_icon_rect.y + icon_height*13/14)
        w = Gdk.scale(ICON_SIZE[0])
        context.set_source_pixbuf(
          gb_foot.load_pixbuf(width: w, height: 9 / 20 * w) { queue_draw }
        )
        context.paint
      end
      context.translate(main_icon_rect.x, main_icon_rect.y)
      context.append_path(Cairo::SpecialEdge.path(*ICON_SIZE.map(&Gdk.method(:scale))))
      context.set_source_rgb(0,0,0)
      context.stroke
      context.append_path(Cairo::SpecialEdge.path(*ICON_SIZE.map(&Gdk.method(:scale))))
      context.set_source_pixbuf(main_icon)
      context.fill
    end
    if not (message.system?)
      render_icon_over_button(context) end
  end

  def render_main_text(context)
    context.save do    # ヘッダ
      context.translate(header_text_rect.x, header_text_rect.y)
      context.set_source_rgb(0,0,0)
      hl_layout = header_left(context)
      context.show_pango_layout(hl_layout)
      hr_layout = header_right(context)
      hr_color = htmlcolor2gdk(Plugin.filtering(:message_header_right_font_color, message, nil).last || BLACK)

      context.save do
        context.translate(header_text_rect.width - (hr_layout.size[0] / Pango::SCALE), 0)
        if (hl_layout.size[0] / Pango::SCALE) > (header_text_rect.width - (hr_layout.size[0] / Pango::SCALE) - 20)
          r, g, b = get_backgroundcolor
          grad = Cairo::LinearPattern.new(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, 0)
          grad.add_color_stop_rgba(0.0, r, g, b, 0.0)
          grad.add_color_stop_rgba(20.0 / (hr_layout.size[0] / Pango::SCALE + 20), r, g, b, 1.0)
          grad.add_color_stop_rgba(1.0, r, g, b, 1.0)
          context.rectangle(-20, 0, hr_layout.size[0] / Pango::SCALE + 20, hr_layout.size[1] / Pango::SCALE)
          context.set_source(grad)
          context.fill()
        end
        context.set_source_rgb(*hr_color)
        context.show_pango_layout(hr_layout)
      end
    end
    context.save do
      context.translate(main_text_rect.x, main_text_rect.y)
      context.show_pango_layout(main_message(context))
    end
  end

  # このMiraclePainterの(x , y)にマウスポインタがある時に表示すべきカーソルの名前を返す。
  # ==== Args
  # [x] x座標(Integer)
  # [y] y座標(Integer)
  # ==== Return
  # [String] カーソルの名前
  def cursor_name_of(x, y)
    index = main_pos_to_index(x, y)
    if index # the cursor is placed on text
      pointed_note = score.find{|note|
        index -= note.description.size
        index <= 0
      }
      if clickable?(pointed_note)
        # the cursor is placed on link
        'pointer'
      else
        'text'
      end
    else
      'default'
    end
  end

  def gb_foot
    self.class.gb_foot
  end

  class << self
    def gb_foot
      @gb_foot ||= Plugin.collect(:photo_filter, Cairo::SpecialEdge::FOOTER_URL, Pluggaloid::COLLECT).first
    end
  end
end
