# -*- coding: utf-8 -*-

require_relative 'model/photo'

module Plugin::Openimg
  ImageOpener = Struct.new(:name, :condition, :open)
end

Plugin.create :openimg do
  # 画像アップロードサービスの画像URLから実際の画像を得る。
  # サービスによってはリファラとかCookieで制御してる場合があるので、
  # "http://twitpic.com/d250g2" みたいなURLから直接画像の内容を返す。
  # String url 画像URL
  # String|nil 画像
  defevent :openimg_raw_image_from_display_url,
           prototype: [String, tcor(IO, nil)]

  # 画像アップロードサービスの画像URLから画像のPixbufを得る。
  defevent :openimg_pixbuf_from_display_url,
           prototype: [String, tcor(:pixbuf, nil), tcor(Thread, nil)]

  # 画像を取得できるURLの条件とその方法を配列で返す
  defevent :openimg_image_openers,
           prototype: [Pluggaloid::COLLECT]

  # 画像を新しいウィンドウで開く
  defevent :openimg_open,
           priority: :ui_response,
           prototype: [String, Diva::Model]

  defdsl :defimageopener do |name, condition, &proc|
    collection :openimg_image_openers do |mutation|
      mutation.add(Plugin::Openimg::ImageOpener.new(name.freeze, condition, proc).freeze)
    end
  end

  filter_openimg_raw_image_from_display_url do |display_url, content|
    unless content
      content = Plugin.collect(:openimg_image_openers).lazy.select{ |opener|
        opener.condition === display_url
      }.map{ |opener|
        opener.open.(display_url)
      }.find(&ret_nth)
      if !content and /\.(?:jpe?g|png|gif|)\z/i.match(display_url)
        begin
          uri = Diva::URI(display_url)
          if uri.scheme == 'file'
            content = File.open(uri.path, 'rb')
          else
            content = URI.open(uri.to_s, 'rb')
          end
        rescue => _
          error _
        end
      end
    end
    [display_url, content]
  end

  on_openimg_open do |display_url|
    Plugin.call(:open, display_url)
  end

  def addsupport(cond, element_rule = {}, &block); end

end
