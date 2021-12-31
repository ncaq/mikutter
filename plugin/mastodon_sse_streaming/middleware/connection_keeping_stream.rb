# frozen_string_literal: true

require_relative '../error'

module Plugin::MastodonSseStreaming::Middleware
  class ConnectionKeepingStream
    def initialize(stream, keeper:)
      @stream = stream
      @cooldown_time = keeper            # CooldownTime
    end

    def to_enum
      Enumerator.new do |yielder|
        loop do
          connect(yielder)
          @cooldown_time.sleep
        end
      end
    end

    def connect(yielder)
      @stream.to_enum.each do |chunk|
        @cooldown_time.reset
        yielder << chunk
      end
      @cooldown_time.client_error
    rescue Plugin::MastodonSseStreaming::ResponseError => exception
      @cooldown_time.status_code(exception.code)
    rescue Plugin::MastodonSseStreaming::ConnectionRefusedError => exception
      notice exception
      @cooldown_time.client_error
    end
  end
end
