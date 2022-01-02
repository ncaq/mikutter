# frozen_string_literal: true

require_relative 'error'

# SSEに接続し、受け取った文字列を列挙するEnumeratorを生成する
module Plugin::MastodonSseStreaming
  class RawServerSentEventsStream
    # @params [Enumerable[String]] connection_type
    def initialize(connection_type)
      # type_strict connection_type => tcor(Plugin::Mastodon::SSEPublicType, Plugin::Mastodon::SSEAuthorizedType)
      @connection_type = connection_type
    end

    def token
      @connection_type.token
    end

    def headers
      if token
        { 'Authorization' => 'Bearer %{token}' % { token: token } }
      else
        {}
      end
    end

    # 接続する
    def to_enum
      Enumerator.new do |yielder|
        client = HTTPClient.new
        client.ssl_config.set_default_paths
        notice "connect #{@connection_type.perma_link} (#{@connection_type})"
        response = client.request(:get, @connection_type.perma_link.to_s, {}, {}, headers) do |fragment|
          yielder << fragment
        end
        if response
          raise ResponseError.new(
            response.reason,
            code: response.status_code,
            response: response
          )
        else
          raise ConnectionRefusedError
        end
      rescue SocketError,
             HTTPClient::BadResponseError,
             HTTPClient::TimeoutError => exception
        raise ConnectionRefusedError, exception.to_s
      end
    end
  end
end
