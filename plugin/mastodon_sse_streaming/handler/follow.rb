# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Follow
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [user, message] SSEで受信したfollowひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Account] user このWorldに対応するユーザをフォローしたユーザ
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'notification'
      case payload
      in type: 'follow', account: Hash => account
        @receiver.(Plugin::Mastodon::Account.new(account))
      else
        # noop
      end
    end
  end
end
