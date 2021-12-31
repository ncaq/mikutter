# frozen_string_literal: true

require_relative 'error'

# JSONLの各行をパースしたものを順番に受け取り、適切なHandlerにルーティングする
module Plugin::MastodonSseStreaming
  class Splitter
    # @params [Enumerable[[String, Hash]]] parsed_sse_stream
    def initialize(parsed_sse_stream)
      @stream = parsed_sse_stream
      @handlers = Set[]
      @handler_lock = Mutex.new
    end

    # @params [Plugin::MastodonSseStreaming::Handler] addition 追加するハンドラ
    def add_handler(addition)
      @handler_lock.synchronize do
        @handlers << addition
      end
      self
    end

    # @params [Plugin::MastodonSseStreaming::Handler] deletion 削除するハンドラ
    # @raises [NoHandlerExsitsError] 削除したあと、Handlerの個数が0になった
    def remove_handler(deletion)
      @handler_lock.synchronize do
        @handlers.delete(deletion)
        raise NoHandlerExsitsError if @handlers.empty?
      end
      self
    end

    # SSEの購読を開始する
    # 接続が切断されるまで戻らない
    def run
      no_mainthread
      @stream.to_enum.each do |(event, data)|
        @handlers.each do |handler|
          handler.(event, data)
        rescue Pluggaloid::NoReceiverError
          remove_handler(handler)
        end
      end
    end
  end
end
