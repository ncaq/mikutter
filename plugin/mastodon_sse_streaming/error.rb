# frozen_string_literal: true

module Plugin::MastodonSseStreaming
  class BaseError < ::StandardError; end

  # SSEのHTTPリクエストが完了し、レスポンスを受け取った
  class ResponseError < BaseError
    attr_reader :code, :response

    def initialize(error_message=nil, code:, response:)
      super(error_message)
      @code = code
      @response = response
    end
  end

  # TCPコネクションが切断され、レスポンスが受け取れない
  class ConnectionRefusedError < BaseError; end

  # Handlerがすべて削除された : このコネクションを切断することを期待
  class NoHandlerExsitsError < BaseError; end
end
