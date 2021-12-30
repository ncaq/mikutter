# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Poll
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [user, message] SSEで受信したpollひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Status] message 投票が締め切られたToot
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'notification'
      case payload
      in type: 'poll', status: Hash => status
        @receiver.(Plugin::Mastodon::Status.build(@connection_type.server, status))
      else
        # noop
      end
    end
  end
end
