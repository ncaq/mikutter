# frozen_string_literal: true

require_relative 'relational_menu'

module Plugin::MastodonAccountViewer
  class RelationalContainer < Gtk::HBox
    ICON_SIZE = Gdk::Rectangle.new(0, 0, 32, 32).freeze
    ARROW_SIZE = Gdk::Rectangle.new(0, 0, 16, 16).freeze

    attr_reader :my_account, :counterpart

    def initialize(my_account, counterpart, updater)
      super(false, ICON_SIZE.width / 2)
      @my_account = my_account
      @counterpart = counterpart
      @updater = updater
      @following = @followed = @blocked = :unknown
      @transaction_level = 0

      closeup(Gtk::WebIcon.new(my_account.account.icon, ICON_SIZE).tooltip(my_account.title))
      closeup(gen_follow_relation)
      closeup(Gtk::WebIcon.new(counterpart.icon, ICON_SIZE).tooltip(counterpart.title))
      closeup(followbutton)
      closeup(menubutton)
      unless me?
        retrieve_relation_status
      end
    end

    def me?
      my_account.account == counterpart
    end

    def following?
      @following == true
    end

    def followed?
      @followed == true
    end

    def blocked?
      @blocked == true
    end

    def mute?
      Plugin::Mastodon::Status.muted?(counterpart.acct)
    end

    # 対象をフォロー／リムーブする。
    # 実際にMastodonにリクエストするのは呼び出し元プラグインへのコールバックで行う
    def request_update_follow_status(new_follow_status)
      promise = if new_follow_status
                  @updater.request_follow(my_account, counterpart)
                else
                  @updater.request_unfollow(my_account, counterpart)
                end
      input_exclusive promise.next do
        relation_transaction do
          @followed = !new_follow_status
        end
      end
    end

    # 対象をミュート／解除する。
    # 実際にMastodonにリクエストするのは呼び出し元プラグインへのコールバックで行う
    def request_update_mute_status(new_mute_status)
      promise = if new_mute_status
                  @updater.request_mute(my_account, counterpart)
                else
                  @updater.request_unmute(my_account, counterpart)
                end
      input_exclusive promise.next do
        refresh_following_pict
      end
    end

    # 対象をブロック／解除する。
    # 実際にMastodonにリクエストするのは呼び出し元プラグインへのコールバックで行う
    def request_update_block_status(new_block_status)
      promise = if new_block_status
                  @updater.request_block(my_account, counterpart)
                else
                  @updater.request_unblock(my_account, counterpart)
                end
      input_exclusive promise.next do
        relation_transaction do
          @blocked = !new_block_status
        end
      end
    end

    private

    def update_button_sensitivity(new_stat)
      followbutton.sensitive = new_stat unless followbutton.destroyed?
      menubutton.sensitive = new_stat unless menubutton.destroyed?
      self
    end

    def following_label
      @following_label ||= Gtk::Label.new(_('関係を取得中'))
    end

    def followed_label
      @followed_label ||= Gtk::Label.new('')
    end

    def eventbox_image_following
      @eventbox_image_following ||= Gtk::EventBox.new
    end

    def eventbox_image_followed
      @eventbox_image_followed ||= Gtk::EventBox.new
    end

    def gen_follow_relation
      Gtk::VBox.new.
        closeup(gen_following_relation).
        closeup(gen_followed_relation)
    end

    def gen_following_relation
      if me?
        Gtk::Label.new(_('それはあなたです！'))
      else
        Gtk::HBox.new.
          closeup(eventbox_image_following).
          closeup(following_label)
      end
    end

    def gen_followed_relation
      Gtk::HBox.new.
        closeup(eventbox_image_followed).
        closeup(followed_label)
    end

    def followbutton
      @followbutton ||= Gtk::Button.new.tap do |b|
        b.sensitive = false
        b.ssc(:clicked) do
          if blocked?
            request_update_block_status(false)
          else
            request_update_follow_status(!following?)
          end
        end
      end
    end

    def menubutton
      @menubutton ||= Gtk::Button.new(' … ').tap do |b|
        b.sensitive = false
        b.ssc(:clicked) do
          Plugin::MastodonAccountViewer::RelationalMenu.new(self).show_all.popup(nil, nil, 0, 0)
          true
        end
      end
    end

    def refresh_following_pict
      return if eventbox_image_following.destroyed?

      unless eventbox_image_following.children.empty?
        eventbox_image_following.remove(eventbox_image_following.children.first)
      end

      eventbox_image_following.style = eventbox_image_following.parent.style
      eventbox_image_following.add(gen_following_arrow_widget)
      following_label.text = gen_follow_status_label_string
      followbutton.label = gen_follow_button_label_string
    end

    def refresh_follower_pict
      return if eventbox_image_followed.destroyed?

      unless eventbox_image_followed.children.empty?
        eventbox_image_followed.remove(eventbox_image_followed.children.first)
      end

      eventbox_image_followed.style = eventbox_image_followed.parent.style
      eventbox_image_followed.add(gen_followed_arrow_widget)
      followed_label.text = gen_followed_status_label_string
    end

    def gen_follow_status_label_string
      if blocked?
        _('ﾌﾞﾖｯｸしている')
      elsif following?
        _('ﾌｮﾛｰしている')
      else
        _('ﾌｮﾛｰしていない')
      end
    end

    def gen_followed_status_label_string
      if followed?
        _('ﾌｮﾛｰされている')
      else
        _('ﾌｮﾛｰされていない')
      end
    end

    def gen_follow_button_label_string
      if blocked? || following?
        _('解除')
      else
        _('ﾌｮﾛｰ')
      end
    end

    def gen_following_arrow_widget
      Gtk::WebIcon.new(Skin[following? ? :arrow_following : :arrow_notfollowing], ARROW_SIZE).show_all
    end

    def gen_followed_arrow_widget
      Gtk::WebIcon.new(Skin.get_path(followed? ? :arrow_followed : :arrow_notfollowed), ARROW_SIZE).show_all
    end

    # Mastodonにアクセスして、現在のフォロー状況を取得し、画面上に反映する
    def retrieve_relation_status
      input_exclusive (Plugin::Mastodon::API.get_local_account_id(my_account, counterpart).next { |aid|
        Plugin::Mastodon::API.call(
          :get,
          my_account.domain,
          '/api/v1/accounts/relationships',
          my_account.access_token,
          id: [aid]
        ).next { |resp| resp[0] }
      }.next { |relationship|
        relation_transaction do
          @following = relationship[:following]
          @followed = relationship[:followed_by]
          @blocked = relationship[:blocking]
        end
      }.trap do |err|
        following_label.text = _('取得できませんでした')
        Deferred.fail(err)
      end)
    end

    def input_exclusive(promise)
      update_button_sensitivity(false)
      promise.next {
        update_button_sensitivity(true)
      }.terminate.trap do
        update_button_sensitivity(true)
      end
    end

    def relation_transaction(&block)
      if @transaction_level == 0
        begin
          following, followed, blocked = @following, @followed, @blocked
          @transaction_level = 1
          result = block.call
          if following != @following || blocked != @blocked
            refresh_following_pict
          end
          if followed != @followed
            refresh_follower_pict
          end
          result
        ensure
          @transaction_level = 0
        end
      else
        begin
          @transaction_level += 1
          block.call
        ensure
          @transaction_level -= 1
        end
      end
    end

    def _(*rest)
      # 翻訳ファイルはプラグインのものを使う必要があるため、Pluginを仮定できない @updater を使わないこと
      Plugin[:mastodon_account_viewer]._(*rest)
    end
  end
end
