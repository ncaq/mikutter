# frozen_string_literal: true

require 'set'

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
end
