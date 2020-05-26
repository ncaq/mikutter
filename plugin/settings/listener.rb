# -*- coding: utf-8 -*-

class Plugin::Settings::Listener
  def self.[](symbol)
    return symbol if(symbol.is_a? Plugin::Settings::Listener)
    Plugin::Settings::Listener.new( get: lambda{
                                      key = Array(symbol).find{|s| UserConfig.include?(s) }
                                      UserConfig[key] if key
                                    },
                                    set: lambda{ |val| UserConfig[Array(symbol).first] = val }) end

  # ==== Args
  # [defaults]
  #   以下の値を含む連想配列。どちらか、またはどちらも省略して良い
  #   _get_ :: _get_.callで値を返すもの
  #   _set_ :: _set_.call(val)で値をvalに設定するもの
  def initialize(default = {})
    value = nil
    if default.has_key?(:get)
      @getter = default[:get]
    else
      @getter = lambda{ value } end
    if default.has_key?(:set)
      @setter = lambda{ |new| default[:set].call(value = new) }
    else
      @setter = lambda{ |new| value = new } end end

  def get(&block)
    if block
      @getter = block
      self
    else
      @getter.call end end

  def set(value=nil, &block)
    if block
      @setter = block
      self
    else
      @setter.call(value) end end

end
