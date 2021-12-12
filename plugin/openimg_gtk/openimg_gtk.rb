# -*- coding: utf-8 -*-

require 'gtk3'
require 'cairo'

module Plugin::OpenimgGtk; end

require_relative 'window'

Plugin.create(:openimg_gtk) do
  UserConfig[:openimg_window_size_width_percent] ||= 70
  UserConfig[:openimg_window_size_height_percent] ||= 70
  UserConfig[:openimg_window_size_reference] ||= :full
  UserConfig[:openimg_window_size_reference_manual_num] ||= 0
  
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

  settings('画像ビューア') do
    settings('ウィンドウサイズ') do
      adjustment('幅 (%)', :openimg_window_size_width_percent, 1, 100)
      adjustment('高さ (%)', :openimg_window_size_height_percent, 1, 100)
      select('サイズの基準', :openimg_window_size_reference) do
        option(:full, 'デスクトップ全体')
        option(:mainwindow, 'メインウィンドウがあるディスプレイ')
        option(:manual, 'ディスプレイ番号を指定') do
          adjustment('ディスプレイ番号', :openimg_window_size_reference_manual_num, 0, 99)
        end
      end
    end
  end
end
