# -*- coding: utf-8 -*-

class Plugin::ChangeAccount::WorldGenerator::Controller
  include Gtk::FormDSL

  def create_inner_setting
    self.class.new(@plugin)
  end

  def initialize(plugin, &block)
    super()
    @plugin = plugin
    @values = Hash.new
    if block_given?
      instance_eval(&block)
    end
  end

  def [](key)
    @values[key.to_sym]
  end

  def []=(key, value)
    @values[key.to_sym] = value
  end

  def to_h(&block)
    if block
      @values.to_h(&block)
k    else
      @values.dup
    end
  end

  def method_missing_at_select_dsl(*args, &block)
    @plugin.__send__(*args, &block)
  end

  def method_missing(*args, &block)
    @plugin.__send__(*args, &block)
  end

end
