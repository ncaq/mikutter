# frozen_string_literal: true

require_relative 'cooldown_time'
require_relative 'error'
require_relative 'middleware/chunk_to_line'
require_relative 'middleware/connection_keeping_stream'
require_relative 'middleware/server_sent_events_json_parser'
require_relative 'raw_server_sent_events_stream'
require_relative 'splitter'

# 接続に必要な情報を構築し、管理する。
# 接続用Threadを作り、リトライ制御などを行う。
module Plugin::MastodonSseStreaming
  class Connection
    def initialize(connection_type)
      @thread_lock = Mutex.new
      @cooldown_time = CooldownTime.new
      @connection = Splitter.new(
        Middleware::ServerSentEventsJSONParser.new(
          Middleware::ChunkToLine.new(
            Middleware::ConnectionKeepingStream.new(
              RawServerSentEventsStream.new(
                connection_type
              ),
              keeper: @cooldown_time
            )
          )
        )
      )
    end

    # @params [Plugin::MastodonSseStreaming::Handler] addition 追加するハンドラ
    def add_handler(addition)
      @thread_lock.synchronize do
        @connection.add_handler(addition)
        unless @thread
          run
        end
      end
      self
    end

    # @params [Plugin::MastodonSseStreaming::Handler] deletion 削除するハンドラ
    def remove_handler(deletion)
      @thread_lock.synchronize do
        @connection.remove_handler(deletion)
      rescue NoHandlerExsitsError
        case @thread
        when Thread.current
          raise
        when Thread
          @thread.kill
          @thread = nil
          notice "#{@connection_type} loses all handler. disconnect"
        end
      end
      self
    end

    private

    # Threadを作り、サーバへ接続する
    # 常に @thread_lock を取っている状態で呼び出すこと
    # add_handlerが、最初のHandlerを追加したときに呼び出すことを期待している
    def run
      raise 'Current thread does not have @thread_lock.' unless @thread_lock.owned?
      @thread&.kill
      @thread = Thread.new do
        Thread.current.abort_on_exception = true
        @connection.run
      rescue NoHandlerExsitsError
        @thread_lock.synchronize do
          @thread = nil if Thread.current == @thread
          notice "#{@connection_type} loses all handler. disconnect"
        end
      end
    end
  end
end
