# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Middleware
=begin yard
SSEのレスポンスを行ごとに分割して列挙されたものを [イベント種別, JSONをパースしたHash] 形式のデータの列挙に変換する
@example
  入力
  [
    "event: status",
    "data: {\"body\":\"みくのおっぱいにおかおをうずめてすーはーすーはーいいかおり！\"}",
    "",
    "event: status",
    "data:{\"body\":\"みくのおっぱい柔らかぁい。柔軟剤使ったのか？\"}",
    ""
  ]
  出力
  [
    [
      "status",
      {
        body: "みくのおっぱいにおかおをうずめてすーはーすーはーいいかおり！"
      }
    ],
    [
      "status",
      {
        body: "みくのおっぱい柔らかぁい。柔軟剤使ったのか？"
      }
    ]
  ]
=end
  class ServerSentEventsJSONParser
    # これら以外のフィールドは無視する（nilは空行検出のため）
    # cf. https://developer.mozilla.org/ja/docs/Server-sent_events/Using_server-sent_events#Event_stream_formata
    EVENT_TYPE_WHITELIST = ['event', 'data', 'id', 'retry', nil].freeze

    # @params [Enumerable[String]] lined_string_stream 行ごとに区切られた文字列を列挙する。ただし、要素となるStringは末尾に改行文字がないこと
    def initialize(lined_string_stream)
      @stream = lined_string_stream
    end

    # 接続する
    def to_enum
      Enumerator.new do |yielder|
        last_type = nil
        data_accumlator = nil
        event_type = nil
        @stream.to_enum.lazy.map { |l|
          l.split(':', 2).map { _1.strip.freeze }
        }.select { |key, _|
          EVENT_TYPE_WHITELIST.include?(key)
        }.each do |type, payload|
          if last_type == 'data' && type != 'data'
            complete_data = data_accumlator.join("\n").freeze
            parsed =
              begin
                JSON.parse(complete_data, symbolize_names: true)
              rescue StandardError => exception
                notice exception
                nil
              end
            yielder << [event_type, parsed] if parsed
            event_type = data_accumlator = nil
          end

          case type
          when nil, 'id', 'retry'
            # noop
            event_type = data_accumlator = nil
          when 'event'
            # イベントタイプ指定
            event_type = payload
          when 'data'
            # データ本体
            if data_accumlator
              data_accumlator << payload
            else
              data_accumlator = [payload]
            end
          end
          last_type = type
        end
      end
    end
  end
end
