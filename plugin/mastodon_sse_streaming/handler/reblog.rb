# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Reblog
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [user, message] SSEで受信したreblogひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Account] user Boostしたユーザ
    # @yieldparam [Plugin::Mastodon::Status] message BoostされたToot
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'notification'
      case payload
      in type: 'reblog', account: Hash => account, status: Hash => status
        @receiver.(Plugin::Mastodon::Account.new(account),
                   Plugin::Mastodon::Status.build(@connection_type.server, status))
      else
        # noop
      end
    end
  end
end
