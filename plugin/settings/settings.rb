# -*- coding: utf-8 -*-

require_relative 'phantom'
require_relative 'listener'

Plugin.create(:settings) do
  # 設定の一覧をPhantomの配列で得る。
  defevent :settings, prototype: [Pluggaloid::COLLECT]

  command(:open_setting,
          name: _('設定'),
          condition: :itself.to_proc,
          visible: true,
          icon: Skin[:settings],
          role: :window) do |opt|
    Plugin.call(:open_setting)
  end

  # 設定画面を作る
  # ==== Args
  # - String name タイトル
  # - Proc &place 設定画面を作る無名関数
  defdsl :settings do |name, &proc|
    name = -name

    collection(:settings) do |mutation|
      mutation << Plugin::Settings::Phantom.new(
        title: name,
        plugin: self,
        &proc
      )
    end

    # 互換性のため
    add_event_filter(:defined_settings) do |tabs|
      [tabs.melt << [name, proc, self.name]]
    end
  end
end
