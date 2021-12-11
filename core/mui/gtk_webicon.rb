# -*- coding: utf-8 -*-

# ／(^o^)＼

require 'environment'
require 'mui/gtk_web_image_loader'
require 'serialthread'
require 'skin'

require 'gtk3'
require 'observer'

# Web上の画像をレンダリングできる。
# レンダリング中は読み込み中の代替イメージが表示され、ロードが終了したら指定された画像が表示される。
# メモリキャッシュ、ストレージキャッシュがついてる。
module Gtk
  class WebIcon < Image
    DEFAULT_RECTANGLE = Gdk::Rectangle.new(0, 0, 48, 48)

    include Observable

    # ==== Args
    # [url] 画像のURLもしくはパス(String)
    # [rect] 画像のサイズ(Gdk::Rectangle) または幅(px)
    # [height] 画像の高さ(px)
    def initialize(url, rect = DEFAULT_RECTANGLE, height = nil)
      rect = Gdk::Rectangle.new(0, 0, rect, height) if height
      case url
      when Diva::Model
        super(pixbuf: load_model(url, rect, set_loading_image: false))
      when GdkPixbuf::Pixbuf
        super(pixbuf: url)
      else
        photo = Plugin.collect(:photo_filter, url, Pluggaloid::COLLECT).first
        super(pixbuf: load_model(photo || Skin[:notfound], rect, set_loading_image: false))
      end
    end

    def load_model(photo, rect, set_loading_image: true)
      loading = photo.load_pixbuf(width: Gdk.scale(rect.width), height: Gdk.scale(rect.height)) do |pb|
        update_pixbuf(pb)
      end
      if set_loading_image
        self.pixbuf = loading
      end
      loading
    end

    def update_pixbuf(pixbuf)
      unless destroyed?
        self.pixbuf = pixbuf
        changed
        notify_observers
      end
    end
  end
end
