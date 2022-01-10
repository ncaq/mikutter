# frozen_string_literal: true

module MIKU::ToRuby
  class Operator
    attr_reader :priority

    # notation = :infix :prefix :method
    def initialize(name, priority:)
      @name = -name.to_s
      @priority = priority.to_i
    end

    def <=>(other)
      @priority <=> other.to_i
    end

    def to_i
      @priority
    end

    def to_s
      @name
    end

    def to_str
      @name
    end

    def inspect
      "#<Operator:#{@name}>"
    end
  end

  # 0  ::
  OPERATOR_NAMESPACE = Operator.new('::', priority: 0)
  # 1  []
  OPERATOR_BRACKET = Operator.new('[]', priority: 1)
  # 2  +(単項)  !  ~
  OPERATOR_UNARY_PLUS = Operator.new('+@', priority: 2)
  OPERATOR_NOT = Operator.new('!', priority: 2)
  OPERATOR_INVERT = Operator.new('~', priority: 2)
  # 3  **
  OPERATOR_POWER = Operator.new('**', priority: 3)
  # 4  -(単項)
  OPERATOR_UNARY_MINUS = Operator.new('-@', priority: 4)
  # 5  *  /  %
  OPERATOR_PRODUCT = Operator.new('*', priority: 5)
  OPERATOR_DIVISION = Operator.new('/', priority: 5)
  OPERATOR_MODULO = Operator.new('%', priority: 5)
  # 6  +  -
  OPERATOR_ADDITION = Operator.new('+', priority: 6)
  OPERATOR_SUBTRACTION = Operator.new('-', priority: 6)
  # 7  << >>
  OPERATOR_BITSHIFT_LEFT = Operator.new('<<', priority: 7)
  OPERATOR_BITSHIFT_RIGHT = Operator.new('>>', priority: 7)
  # 8  &
  OPERATOR_BITWISE_AND = Operator.new('&', priority: 8)
  # 9  |  ^
  OPERATOR_BITWISE_OR = Operator.new('|', priority: 9)
  OPERATOR_BITWISE_XOR = Operator.new('^', priority: 9)
  # 10 > >=  < <=
  OPERATOR_LESS_THAN = Operator.new('>', priority: 10)
  OPERATOR_LESS_THAN_OR_EQUAL = Operator.new('>=', priority: 10)
  OPERATOR_GREATER_THAN = Operator.new('<', priority: 10)
  OPERATOR_GREATER_THAN_OR_EQUAL = Operator.new('<=', priority: 10)
  # 11 <=> ==  === !=  =~  !~
  OPERATOR_SPACESHIP = Operator.new('<=>', priority: 11)
  OPERATOR_EQUAL = Operator.new('==', priority: 11)
  OPERATOR_SAME = Operator.new('===', priority: 11)
  OPERATOR_NOT_EQUAL = Operator.new('!=', priority: 11)
  OPERATOR_MATCH = Operator.new('=~', priority: 11)
  OPERATOR_NOT_MATCH = Operator.new('!~', priority: 11)
  # 12 &&
  OPERATOR_LOGICAL_AND = Operator.new('&&', priority: 12)
  # 13 ||
  OPERATOR_LOGICAL_OR = Operator.new('||', priority: 13)
  # 14 ..  ...
  OPERATOR_RANGE = Operator.new('..', priority: 14)
  OPERATOR_RANGE_EXCLUSIVE_END = Operator.new('...', priority: 14)
  # 15 ?:(条件演算子)
  OPERATOR_CONDITION = Operator.new('?:', priority: 15)
  # 16 =(+=, -= ... )
  # OPERATOR_ASSIGN_PLUS = Operator.new('+=', priority: 16)
  # 17 not
  OPERATOR_NOT_STRING = Operator.new('not', priority: 17)
  # 18 and or
  OPERATOR_AND_STRING = Operator.new('and', priority: 18)
  OPERATOR_OR_STRING = Operator.new('or', priority: 18)
end
