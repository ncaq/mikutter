# frozen_string_literal: true

module Plugin::MastodonSseStreaming
  class BaseError < ::StandardError; end

  class ResponseError < BaseError
    attr_reader :code, :response

    def initialize(error_message=nil, code:, response:)
      super(error_message)
      @code = code
      @response = response
    end
  end

  class ConnectionRefusedError < BaseError; end
end
