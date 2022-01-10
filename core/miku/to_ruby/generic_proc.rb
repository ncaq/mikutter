# frozen_string_literal: true

module MIKU::ToRuby
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
end
