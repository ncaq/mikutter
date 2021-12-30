# frozen_string_literal: true

require_relative 'error'

# JSONLの各行をパースしたものを順番に受け取り、適切なHandlerにルーティングする
module Plugin::MastodonSseStreaming
  class Splitter
    # @params [Enumerable[[String, Hash]]] parsed_sse_stream
    def initialize(parsed_sse_stream)
      @stream = parsed_sse_stream
      @handlers = Set[]
    end

    # @params [Plugin::MastodonSseStreaming::Handler] addition 追加するハンドラ
    def add_handler(addition)
      @handlers << addition
      self
    end

    # @params [Plugin::MastodonSseStreaming::Handler] deletion 削除するハンドラ
    def remove_handler(deletion)
      @handlers.delete(deletion)
      self
    end

    # SSEの購読を開始する
    # 接続が切断されるまで戻らない
    def run
      no_mainthread
      @stream.to_enum.each do |(event, data)|
        @handlers.each do |handler|
          handler.(event, data)
        end
      end
    end
  end
end
