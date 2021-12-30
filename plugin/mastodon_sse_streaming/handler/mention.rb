# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Mention
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [user, message] SSEで受信したmentionひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Status] message 受信したMention
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'notification'
      case payload
      in type: 'mention', status: Hash => status
        @receiver.(Plugin::Mastodon::Status.build(@connection_type.server, status))
      else
        # noop
      end
    end
  end
end
