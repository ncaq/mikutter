# -*- coding: utf-8 -*-

# プラグインを全てロードする
require_relative 'prepare_plugin'

if Mopt.plugin.is_a? Array
  ['core', *Mopt.plugin].uniq.each(&Miquire::Plugin.method(:load))
else
  Miquire::Plugin.load_all
end
