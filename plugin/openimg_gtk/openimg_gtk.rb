# -*- coding: utf-8 -*-

require 'gtk3'
require 'cairo'

module Plugin::OpenimgGtk; end

require_relative 'window'

Plugin.create(:openimg_gtk) do
  filter_openimg_pixbuf_from_display_url do |photo, loader, thread|
    loader = GdkPixbuf::PixbufLoader.new
    [photo, loader, photo.download{|partial| loader.write partial }]
  end

  intent Plugin::Openimg::Photo do |intent_token|
    Plugin::OpenimgGtk::Window.new(intent_token.model, intent_token).start_loading.show_all
  end

  intent :photo do |intent_token|
    Plugin::OpenimgGtk::Window.new(intent_token.model, intent_token).start_loading.show_all
  end
end
