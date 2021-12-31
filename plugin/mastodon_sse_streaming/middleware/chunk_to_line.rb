# frozen_string_literal: true

module Plugin::MastodonSseStreaming::Middleware
=begin yard
Stringが列挙されるEnumerableを受け取り、それらを順番に連結して
改行区切りで列挙するEnumeratorに変換する。
これが列挙するStringは、末尾に改行を含まない。
@example
  入力
  [
    "event: status\ndata: {body:\"みくのおっぱいにおかおをうずめて",
    "すーはーすーは\ndata: ーいいかおり！\"}\nevent: status\ndata:",
    "{body:\"みくのおっぱい柔らかぁい。柔軟剤使ったのか？\"}\n"
  ]
  出力
  [
    "event: status",
    "data: {body:\"みくのおっぱいにおかおをうずめてすーはーすーは",
    "data: ーいいかおり！'}",
    "event: status",
    "data:{body:'みくのおっぱい柔らかぁい。柔軟剤使ったのか？'}"
  ]
=end
  class ChunkToLine
    # @params [Enumerable[String]] raw_string_stream
    def initialize(raw_string_stream)
      @stream = raw_string_stream
    end

    # 接続する
    def to_enum
      Enumerator.new do |yielder|
        data_accumlator = []
        @stream.to_enum.each do |chunk|
          offset = 0
          while index = chunk.index("\n", offset)
            yielder << [*data_accumlator, chunk[offset...index]].join.freeze
            data_accumlator = []
            offset = index + 1
          end
          data_accumlator << chunk[offset..]
        end
      end
    end
  end
end
