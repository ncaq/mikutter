# frozen_string_literal: true

require 'set'
require 'delegate'

module MIKU::ToRuby
  class Type
    attr_reader :types

    def initialize(*types, freeze: false)
      @types = types.to_set.freeze
      @mutable = !freeze
    end

    def mutable?
      @mutable
    end

    def immutable?
      !@mutable
    end

    def subset?(other)
      @types.subset?(other.types)
    end

    def intersect?(other)
      @types.intersect?(other.types)
    end

    def |(other)
      fusion = (@types | other.types).group_by(&:class)
      new_types = Set.new(fusion.delete(Class))
      fusion.each_value do |types|
        new_types << types.inject(&:|)
      end
      Type.new(new_types, freeze: immutable? & other.immutable?)
    end

    def to_s
      x = mutable? ? '' : ' frozen'
      "#<Type:#{types.join('|')}#{x}>"
    end

    def inspect
      to_s
    end
  end

  ANY = Type.new(BasicObject)
  NIL_TYPE = Type.new(NilClass, freeze: true)
  TRUE_TYPE = Type.new(TrueClass, freeze: true)
  FALSE_TYPE = Type.new(FalseClass, freeze: true)
  BOOLEAN_TYPE = TRUE_TYPE | FALSE_TYPE
  FALSY_TYPE = FALSE_TYPE | NIL_TYPE
  LOGICAL_TYPE = BOOLEAN_TYPE | NIL_TYPE

  class GenericProc
    attr_reader :return_type

    def initialize(return_type)
      @return_type = return_type
    end

    def |(other)
      self.class.new(@return_type.types | other.return_type.types)
    end

    def to_s
      "#<Type:Proc -> #{@return_type}>"
    end

    def inspect
      to_s
    end
  end

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

    def inspect
      x = ["p=#{@priority}", "t=#{@type}"]
      x << 'taint' if taint?
      x << 'affect' if affect?
      x << 'pure' if pure?
      "#{super}<#{x.join(',')}>"
    end
  end
end
