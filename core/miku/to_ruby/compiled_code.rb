# frozen_string_literal: true

require 'delegate'

require_relative 'type'

module MIKU::ToRuby
  class CompiledCode < SimpleDelegator
    attr_reader :type, :priority

    # @params [Boolean] taint Scopeを変化させる
    # @params [Boolean] affect Scopeに影響を受けて実行結果が変化する
    # @params [Array[Class]|ANY] type 式の評価結果の型
    def initialize(str, taint:, affect:, type: ANY, priority: -1)
      super(str.to_s.freeze)
      @type = type
      @priority = priority.to_i
      @taint = taint
      @affect = affect
    end

    def indent
      __setobj__(each_line.map { "  #{_1.chomp}" }.join("\n").freeze)
      self
    end

    def attach_paren
      if @priority > -1
        @priority = -1
        __setobj__("(#{self})")
      end
      self
    end

    def single_line?
      each_line.take(2).size == 1
    end

    def taint?
      @taint
    end

    def affect?
      @affect
    end

    def pure?
      !(taint? || affect?)
    end

    def deconstruct_keys(_keys)
      {
        taint: @taint,
        affect: @affect,
        pure: pure?,
        priority: @priority,
        type: @type
      }
    end

    def inspect
      x = ["p=#{@priority}", "t=#{@type}"]
      x << 'taint' if taint?
      x << 'affect' if affect?
      x << 'pure' if pure?
      "#{super}<#{x.join(',')}>"
    end
  end
end
