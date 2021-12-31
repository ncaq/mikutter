# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Favorite
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [user, message] SSEで受信したfavoriteひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Account] user ふぁぼったユーザ
    # @yieldparam [Plugin::Mastodon::Status] message ふぁぼられたToot
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'notification'
      case payload
      in type: 'favourite', account: Hash => account, status: Hash => status
        user = Plugin::Mastodon::Account.new(account)
        message = Plugin::Mastodon::Status.build(@connection_type.server, status)
        message.favorite_accts << user.acct
        message.set_modified(Time.now.localtime) if favorite_age?(user)
        @receiver.(user, message)
      else
        # noop
      end
    end

    private

    def favorite_age?(user)
      if user.me?
        UserConfig[:favorited_by_myself_age]
      else
        UserConfig[:favorited_by_anyone_age]
      end
    end
  end
end
