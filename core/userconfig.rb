# -*- coding: utf-8 -*-

require 'configloader'
require 'plugin'

require 'singleton'
require 'fileutils'

#
#= UserConfig 動的な設定
#
#プログラムから動的に変更される設定。
#プラグインの設定ではないので注意。
class UserConfig
  include Singleton
  include ConfigLoader
  extend MonitorMixin
  #
  # 予約された設定一覧
  #

  @@defaults = {
    # デフォルトのフッダ
    :footer => "",

    # リプライ元を常に取得する
    :retrieve_force_mumbleparent => true,

    # つぶやきを投稿するキー
    :shortcutkey_keybinds => {1 => {:key => "Control + Return", :name => '投稿する', :slug => :post_it}},

    # リクエストをリトライする回数
    :message_retry_limit => 10,

    # 通知を表示しておく秒数
    :notify_expire_time => 10,

    :retweeted_by_anyone_show_timeline => true,

    :retweeted_by_anyone_age => true,

    :favorited_by_anyone_show_timeline => true,

    :favorited_by_anyone_age => true,

    # プロフィールタブの並び順
    :profile_tab_order => [:usertimeline, :aboutuser, :list],

    # 設定タブの並び順
    :tab_order_in_settings => ["基本設定", "表示", "入力", "通知", "抽出タブ", "リスト", "ショートカットキー", "アカウント情報", "プロキシ"],

    # タブの位置 [上,下,左,右]
    :tab_position => 3,

    # 常にURLを短縮して投稿
    :shrinkurl_always => false,

    # 常にURLを展開して表示
    :shrinkurl_expand => true,

    # 非公式RTにin_reply_to_statusをつける
    :legacy_retweet_act_as_reply => false,

    :bitly_user => '',
    :bitly_apikey => '',

    :mumble_basic_font => 'Sans 10',
    :mumble_basic_color => [0, 0, 0],
    :reply_text_font => 'Sans 8',
    :reply_text_color => [0, 0, 0],
    :quote_text_font => 'Sans 8',
    :quote_text_color => [0, 0, 0],
    :mumble_basic_left_font => 'Sans 10',
    :mumble_basic_left_color => [0, 0, 0],
    :mumble_basic_right_font => 'Sans 10',
    :mumble_basic_right_color => [0x9999, 0x9999, 0x9999],

    :mumble_basic_bg => [0xffff, 0xffff, 0xffff],
    :mumble_reply_bg => [0xffff, 0xdede, 0xdede],
    :mumble_self_bg => [0xffff, 0xffff, 0xdede],
    :mumble_selected_bg => [0xdede, 0xdede, 0xffff],
    :replyviewer_background_color => [0xffff, 0xdede, 0xdede],
    :quote_background_color => [0xffff, 0xffff, 0xffff],

    :reply_icon_size => 32,
    :quote_icon_size => 32,

    :reply_present_policy => %i<header icon edge>,
    :reply_edge => :solid,

    :quote_present_policy => %i<header icon edge>,
    :quote_edge => :solid,

    # 右クリックメニューの並び順
    :mumble_contextmenu_order => ['copy_selected_region',
                                  'copy_description',
                                  'reply',
                                  'reply_all',
                                  'retweet',
                                  'delete_retweet',
                                  'legacy_retweet',
                                  'favorite',
                                  'delete_favorite',
                                  'delete'],

    :subparts_order => ["Gdk::ReplyViewer", "Gdk::SubPartsFavorite", "Gdk::SubPartsShare"],

    :activity_mute_kind => ["error"],
    :activity_show_timeline => ["system", "achievement"],

    :notification_enable => true,

    :reply_text_max_line_count => 10,
    :quote_text_max_line_count => 10,
    :reply_clicked_action => :open,
    :quote_clicked_action => :open,

    :intent_selector_rules => [],

    :postbox_visibility => :auto,
    :world_shifter_visibility => :auto,

    :miraclepainter_expand_custom_emoji => true,
    :ui_scale => :auto
  }

  @@watcher = Hash.new{ [] }
  @@watcher_id = Hash.new
  @@watcher_id_count = 0

  # キーに対応する値が存在するかを調べる。
  # 値が設定されていれば、それが _nil_ や _false_ であっても _true_ を返す
  # ==== Args
  # [key] Symbol キー
  # ==== Return
  # [true] 存在する
  # [false] 存在しない
  def self.include?(key)
    UserConfig.instance.include?(key) || @@defaults.include?(key)
  end

  # 設定名 _key_ にたいする値を取り出す
  # 値が設定されていない場合、nilを返す。
  def self.[](key)
    UserConfig.instance.at(key, @@defaults[key.to_sym])
  end

  # 設定名 _key_ に値 _value_ を関連付ける
  def self.[]=(key, val)
    Plugin.call(:userconfig_modify, key, val)
    watchers = synchronize{
      if not(@@watcher[key].empty?)
        before_val = UserConfig.instance.at(key, @@defaults[key.to_sym])
        @@watcher[key].map{ |id|
          proc = if @@watcher_id.has_key?(id)
                   @@watcher_id[id]
                 else
                   @@watcher[key].delete(id)
                   nil end
          lambda{ proc.call(key, val, before_val, id) } if proc } end }
    if watchers.is_a? Enumerable
      watchers.each{ |w| w.call if w } end
    UserConfig.instance.store(key, val)
  end

  # 設定名 _key_ の値が変更されたときに、ブロック _watcher_ を呼び出す。
  # watcher_idを返す。
  def self.connect(key, &watcher)
    synchronize{
      id = @@watcher_id_count
      @@watcher_id_count += 1
      @@watcher[key] = @@watcher[key].push(id)
      @@watcher_id[id] = watcher
      id
    }
  end

  # watcher idが _id_ のwatcherを削除する。
  def self.disconnect(id)
    synchronize{
      @@watcher_id.delete(id)
    }
  end

  def self.setup
    last_boot_version = UserConfig[:last_boot_version] || [0, 0, 0, 0]
    if last_boot_version < Environment::VERSION.to_a
      UserConfig[:last_boot_version] = Environment::VERSION.to_a
      if last_boot_version == [0, 0, 0, 0]
        key_add "Alt + x", "コンソールを開く", :console_open
        UserConfig[:postbox_visibility] = :always
        UserConfig[:world_shifter_visibility] = :always
      end
      if last_boot_version < [3, 3, 0, 0]
        UserConfig[:notification_enable] = true
        activity_show_statusbar = (UserConfig[:activity_show_statusbar] || []).map(&:to_s)
        unless activity_show_statusbar.include? 'streaming_status'
          activity_show_statusbar << 'streaming_status'
          UserConfig[:activity_show_statusbar] = activity_show_statusbar end end
      if last_boot_version < [3, 4, 0, 0]
        UserConfig[:replyviewer_background_color] = UserConfig[:mumble_reply_bg]
        UserConfig[:quote_background_color] = UserConfig[:mumble_basic_bg]
        UserConfig[:reply_text_font] = UserConfig[:mumble_reply_font] || 'Sans 8'
        UserConfig[:reply_text_color] = UserConfig[:mumble_reply_color] || [0x6666, 0x6666, 0x6666]
        UserConfig[:reply_icon_size] = 24
        UserConfig[:quote_text_font] = UserConfig[:reply_text_font] || 'Sans 8'
        UserConfig[:quote_text_color] = UserConfig[:reply_text_color]
        UserConfig[:reply_present_policy] = %i<icon>
        UserConfig[:quote_edge] = :floating
        UserConfig[:reply_text_max_line_count] = 3
        UserConfig[:reply_clicked_action] = nil
        UserConfig[:quote_clicked_action] = :smartthread
      end
    end
  end

  def self.key_add(key, name, slug)
    type_strict key => String, name => String, slug => Symbol
    keys = UserConfig[:shortcutkey_keybinds].melt
    keys[(keys.keys.max || 0)+1] = {
      :key => key,
      :name => name,
      :slug => slug}
    UserConfig[:shortcutkey_keybinds] = keys end

  setup

end
