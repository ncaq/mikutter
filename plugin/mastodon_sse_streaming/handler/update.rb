# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Handler
  class Update
    # @param [Plugin::Mastodon::SSEAuthorizedType|Plugin::Mastodon::SSEPublicType] connection_type
    # @yield [message] SSEで受信したTootひとつにつき一度呼ばれる
    # @yieldparam [Plugin::Mastodon::Status] message 受信したToot
    def initialize(connection_type, &receiver)
      @connection_type = connection_type
      @receiver = receiver
    end

    # @params [String] event
    # @params [Hash] payload
    def call(event, payload)
      return if event != 'update'
      message = Plugin::Mastodon::Status.build(@connection_type.server, payload)
      if message
        @receiver.(message)
        Plugin.call(:update, nil, [message]) # 互換性のため
      end
    end
  end
end
