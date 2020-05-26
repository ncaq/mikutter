# -*- coding: utf-8 -*-

require_relative 'pane'
require_relative 'cuscadable'
require_relative 'hierarchy_child'
require_relative 'tab'
require_relative 'widget'

class Plugin::GUI::Timeline

  include Plugin::GUI::Cuscadable
  include Plugin::GUI::HierarchyChild
  include Plugin::GUI::HierarchyParent
  include Plugin::GUI::Widget

  include Enumerable

  role :timeline

  set_parent_event :gui_timeline_join_tab

  def initialize(*args)
    super
    Plugin.call(:timeline_created, self)
  end

  def <<(argument)
    messages = argument.is_a?(Enumerable) ? argument : Array[argument]
    Plugin.call(:gui_timeline_add_messages, self, messages)
  end

  # タイムラインの中のツイートを全て削除する
  def clear
    Plugin.call(:gui_timeline_clear, self) end

  # タイムラインの一番上にスクロール
  def scroll_to_top
    Plugin.call(:gui_timeline_scroll_to_top, self) end

  # このタイムラインをアクティブにする。また、子のPostboxは非アクティブにする
  # ==== Return
  # self
  def active!(just_this=true, by_toolkit=false)
    set_active_child(nil, by_toolkit) if just_this
    super end

  # タイムラインに _messages_ が含まれているなら真を返す
  # ==== Args
  # [*messages] Message タイムラインに含まれているか確認するMessageオブジェクト。配列や引数で複数指定した場合は、それら全てが含まれているかを返す
  # ==== Return
  # _messages_ が含まれているなら真
  def include?(*messages)
    args = messages.flatten.freeze
    detected = Plugin.filtering(:gui_timeline_select_messages, self, args)
    detected.is_a? Array and detected[1].size == args.size end

  # _messages_ のうち、Timelineに含まれているMessageを返す
  # ==== Args
  # [messages] Enumerable タイムラインに含まれているか確認するMessage
  # ==== Return
  # Enumerable _messages_ で指定された中で、selfに含まれるもの
  def in_message(messages)
    detected = Plugin.filtering(:gui_timeline_select_messages, self, messages)
    if detected.is_a? Enumerable
      detected[1]
    else
      [] end end

  # _messages_ のうち、Timelineに含まれていないMessageを返す
  # ==== Args
  # [messages] Enumerable タイムラインに含まれているか確認するMessageオブジェクト
  # ==== Return
  # Enumerable _messages_ で指定された中で、selfに含まれていないもの
  def not_in_message(messages)
    detected = Plugin.filtering(:gui_timeline_reject_messages, self, messages)
    if detected.is_a? Enumerable
      detected[1]
    else
      [] end end

  # 選択されているMessageを返す
  # ==== Return
  # 選択されているMessage
  def selected_messages
    messages = Plugin.filtering(:gui_timeline_selected_messages, self, [])
    messages[1] if messages.is_a? Array end

  # _in_reply_to_message_ に対するリプライを入力するPostboxを作成してタイムライン上に表示する
  # ==== Args
  # [in_reply_to_message] リプライ先のツイート
  # [options] Postboxのオプション
  def create_reply_postbox(in_reply_to_message, options = {})
    create_postbox(options.merge(to: [in_reply_to_message],
                                 header: "@#{in_reply_to_message.user.idname} "))
  end

  # _in_reply_to_message_ に対するリプライを入力するPostboxを作成してタイムライン上に表示する
  # ==== Args
  # [options] Postboxのオプション
  def create_postbox(options = {})
    i_postbox = Plugin::GUI::Postbox.instance
    i_postbox.options = options
    self.add_child i_postbox
  end

  # Postboxを作成してこの中に入れる
  # ==== Args
  # [options] 設定値
  # ==== Return
  # 新しく作成したPostbox
  def postbox(options = {})
    postbox = Plugin::GUI::Postbox.instance
    postbox.options = options
    self.add_child postbox
    postbox
  end

  # このタイムライン内の _message_ の部分文字列が選択されている場合それを返す。
  # 何も選択されていない場合はnilを返す
  # ==== Args
  # [message] 調べるMessageのインスタンス
  # ==== Return
  # 選択されたテキスト
  def selected_text(message)
    result = Plugin.filtering(:gui_timeline_selected_text, self, message, nil)
    result.last if result end

  # Messageを並べる順序を数値で返すブロックを設定する
  # ==== Args
  # [&block] 並び順
  # ==== Return
  # self
  def order(&block)
    Plugin.call(:gui_timeline_set_order, self, block)
  end

  # このタイムライン内の _message_ を繰り返し処理する
  def each(&block)
    if block
      Plugin.collect(:gui_timeline_each_messages, self).each(&block)
    else
      Plugin.collect(:gui_timeline_each_messages, self)
    end
  end

  def size
    to_a.size
  end

  # timeline_maxを取得する
  def timeline_max
    Plugin.filtering(:gui_timeline_get_timeline_max, self, nil)[1] || UserConfig[:timeline_max]
  end

  # timeline_maxを設定する
  def timeline_max=(n)
    Plugin.filtering(:gui_timeline_set_timeline_max, self, n)
  end
end
