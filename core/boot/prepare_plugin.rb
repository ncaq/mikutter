# frozen_string_literal: true
# プラグインのロードパスを構築する

require 'miquire_plugin'

Environment::PLUGIN_PATH.each do |path|
  Miquire::Plugin.loadpath << path
end
Miquire::Plugin.loadpath << File.join(Environment::CONFROOT, 'plugin')
