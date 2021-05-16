 # -*- coding: utf-8 -*-

module Plugin::Settings
  DSL_METHODS = [
    :label,
    :settings,
    :create_inner_setting,
    :multitext,
    :fileselect,
    :photoselect,
    :font,
    :select,
    :dirselect,
    :inputpass,
    :multi,
    :about,
    :listview,
    :fontcolor,
    :multiselect,
    :adjustment,
    :keybind,
    :color,
    :link,
    :input,
    :boolean
  ]
  # Setting DSLの、入れ子になったsettingsだけを抜き出すためのクラス。
  class Phantom
    attr_reader :title, :plugin

    def initialize(title:, plugin:, &block)
      raise ArgumentError, 'Block requred.' unless block
      @title = -title
      @plugin = plugin
      @proc = block
      @children = nil
    end

    def children
      return @children if @children
      @children = []
      instance_eval(&@proc)
      @children.freeze
    rescue
      @children = [].freeze
    end

    def to_proc
      @proc
    end

    DSL_METHODS.each do |name|
      define_method(name) do |*|
        MOCK
      end
    end

    def settings(name, &block)
      @children << Phantom.new(
        title: name,
        plugin: @plugin,
        &block
      )
      nil
    end

    def method_missing(name, *rest, &block)
      case name.to_sym
      when *DSL_METHODS
        MOCK
      else
        @plugin.__send__(name, *rest, &block)
      end
    end

    class Mock
      def method_missing(name, *rest, **kwrest, &block)
        MOCK
      end
    end

    MOCK = Mock.new

  end

end
