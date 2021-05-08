# -*- coding: utf-8 -*-

Plugin.create(:mastodon_custom_post) do
  command(
    :mastodon_custom_post,
    name: _('カスタム投稿'),
    condition: ->(opt) do
      mastodon?(opt.world) && opt.widget.editable?
    end,
    visible: true,
    icon: Skin[:post],
    role: :postbox
  ) do |opt|
    i_postbox = opt.widget
    postbox, = Plugin.filtering(:gui_get_gtk_widget, i_postbox)
    body = postbox.widget_post.buffer.text
    reply_to = postbox.mastodon_get_reply_to

    dialog _('カスタム投稿') do
      # オプションを並べる
      multitext _('CW警告文'), :spoiler_text
      self[:body] = body
      multitext _('本文'), :body
      self[:sensitive] = opt.world.account.source.sensitive
      boolean _('閲覧注意'), :sensitive

      visibility_default = opt.world.account.source.privacy
      if reply_to.is_a?(Plugin::Mastodon::Status) && reply_to.visibility == "direct"
        # 返信先がDMの場合はデフォルトでDMにする。但し編集はできるようにするため、この時点でデフォルト値を代入するのみ。
        visibility_default = "direct"
      end
      self[:visibility] = Plugin::Mastodon::Util.visibility2select(visibility_default)
      select _('公開範囲'), :visibility do
        option :"1public", _('公開')
        option :"2unlisted", _('未収載')
        option :"3private", _('非公開')
        option :"4direct", _('ダイレクト')
      end

      settings _('添付メディア') do
        # mikutter-uwm-hommageの設定を勝手に持ってくる
        dirs = 10.times.map { |i|
          UserConfig["galary_dir#{i + 1}".to_sym]
        }.compact.reject(&:empty?)

        fileselect "", :media1, shortcuts: dirs, use_preview: true
        fileselect "", :media2, shortcuts: dirs, use_preview: true
        fileselect "", :media3, shortcuts: dirs, use_preview: true
        fileselect "", :media4, shortcuts: dirs, use_preview: true
      end

      settings _('投票を受付ける') do
        input "1", :poll_options1
        input "2", :poll_options2
        input "3", :poll_options3
        input "4", :poll_options4
        select _('投票受付期間'), :poll_expires_in do
          option :min5, _('5分')
          option :hour, _('1時間')
          option :day, _('1日')
          option :week, _('1週間')
          option :month, _('1ヶ月')
        end
        boolean _('複数選択可にする'), :poll_multiple
        boolean _('終了するまで結果を表示しない'), :poll_hide_totals
      end
    end.next do |result|
      # 投稿
      # まず画像をアップロード
      media_ids = []
      media_urls = []
      (1..4).each do |i|
        if result[:"media#{i}"]
          path = Pathname(result[:"media#{i}"])
          hash = +Plugin::Mastodon::API.call(:post, opt.world.domain, '/api/v1/media', opt.world.access_token, file: path) # TODO: Deferred.whenを使えば複数枚同時アップロードできる
          media_ids << hash[:id].to_i
          media_urls << hash[:text_url]
        end
      end
      # 画像がアップロードできたらcompose spellを起動
      opts = {
        body: result[:body]
      }
      if !media_ids.empty?
        opts[:media_ids] = media_ids
      end
      if !result[:spoiler_text].empty?
        opts[:spoiler_text] = result[:spoiler_text]
      end
      opts[:sensitive] = result[:sensitive]
      opts[:visibility] = Plugin::Mastodon::Util.select2visibility(result[:visibility])

      if (1..4).any?{|i| result[:"poll_options#{i}"] }
        opts[:poll] = Hash.new
        opts[:poll][:expires_in] = case result[:poll_expires_in]
                                   when :min5
                                     5 * 60 + 1 # validation error回避のための+1
                                   when :hour
                                     60 * 60
                                   when :day
                                     24 * 60 * 60
                                   when :week
                                     7 * 24 * 60 * 60
                                   when :month
                                     (Date.today.next_month - Date.today).to_i * 24 * 60 * 60 - 1 # validation error回避のための-1
                                   end
        opts[:poll][:multiple] = !!result[:poll_multiple]
        opts[:poll][:hide_totals] = !!result[:poll_hide_totals]
        opts[:poll][:options] = (1..4).map{|i| result[:"poll_options#{i}"] }.compact
      end

      compose(opt.world, reply_to, **opts)

      if Gtk::PostBox.list[0] != postbox
        postbox.destroy
      else
        postbox.widget_post.buffer.text = ''
      end
    end
  end
end
