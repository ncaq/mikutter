# -*- coding: utf-8 -*-

require_relative 'to_ruby/compiled_code'
require_relative 'to_ruby/operator'

module MIKU
  module ToRuby
    STRING_LITERAL_ESCAPE_MAP = {'\\' => '\\\\', "'" => "\\'"}.freeze
    STRING_LITERAL_ESCAPE_MATCHER = Regexp.union(STRING_LITERAL_ESCAPE_MAP.keys).freeze
    OPERATOR_DICT = {           # MIKU_FUNCNAME => Operator
      :< => OPERATOR_GREATER_THAN,
      :> => OPERATOR_LESS_THAN,
      :<= => OPERATOR_GREATER_THAN_OR_EQUAL,
      :>= => OPERATOR_LESS_THAN_OR_EQUAL,
      :eql => OPERATOR_EQUAL,
      equal: OPERATOR_SAME,
      and: OPERATOR_LOGICAL_AND,
      or: OPERATOR_LOGICAL_OR,
      :== => OPERATOR_EQUAL,
      eq: Operator.new('equal?', priority: -1),
      :+ => OPERATOR_ADDITION,
      :- => OPERATOR_SUBTRACTION,
      :* => OPERATOR_PRODUCT,
      :/ => OPERATOR_DIVISION,
    }.freeze

    class << self
      def progn(list, quoted: false, use_result: true)
        if options[:use_result]
          *progn_expr, return_expr = list
          progn_codes = progn_expr.map { |n| to_ruby(n, use_result: false) }
          return_code = to_ruby(return_expr, use_result: :to_return)
          codes = [*progn_codes, return_code]
          CompiledCode.new(
            codes.join("\n"),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: return_code.type
          )
        else
          codes = list.map { to_ruby(_1, use_result: false) }
          CompiledCode.new(
            codes.join("\n"),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: codes.last.type
          )
        end
      end

      # rubyに変換して返す
      # 
      # ==== Args
      # [sexp] MIKUの式(MIKU::Nodeのインスタンス)
      # [options] 以下の値を持つHash
      #   quoted :: 真ならクォートコンテキスト内。シンボルが変数にならず、シンボル定数になる
      #   use_result :: 結果を使うなら真。そのコンテキストの戻り値として使うだけなら、 :to_return を指定
      def to_ruby(sexp, options={quoted: false, use_result: true})
        expanded = sexp
        case expanded
        when :true, TrueClass
          CompiledCode.new('true', taint: false, affect: false, type: TRUE_TYPE)
        when :false, FalseClass
          CompiledCode.new('false', taint: false, affect: false, type: FALSE_TYPE)
        when :nil, NilClass
          CompiledCode.new('nil', taint: false, affect: false, type: NIL_TYPE)
        when Symbol
          if options[:quoted]
            CompiledCode.new(
              ":#{expanded}",
              taint: false,
              affect: false,
              type: Type.new(Symbol, freeze: true)
            )
          else
            CompiledCode.new(
              expanded,
              taint: true,
              affect: true,
              type: ANY
            )
          end
        when Numeric
          CompiledCode.new(expanded, taint: false, affect: false, type: Type.new(expanded.class, freeze: true))
        when String
          string_literal(expanded)
        when List
          if options[:quoted]
            codes = expanded.map{|node| to_ruby(node, quoted: true, use_result: true)}
            CompiledCode.new(
              '[' + codes.join(', ') + ']',
              taint: codes.any?(&:taint?),
              affect: codes.any?(&:affect?),
              type: Type.new(Array, freeze: false)
            )
          else
            call_method(expanded)
          end
        else
          CompiledCode.new(expanded.to_s, taint: true, affect: true)
        end
      end

      def string_literal(str)
        escaped = str.gsub(STRING_LITERAL_ESCAPE_MATCHER, STRING_LITERAL_ESCAPE_MAP)
        CompiledCode.new(
          "-'#{escaped}'",
          taint: false,
          affect: false,
          type: Type.new(String, freeze: true),
          priority: OPERATOR_UNARY_MINUS
        )
      end

      def call_method(expanded, quoted: false, use_result: true)
        case expanded
        in [:quote, expr]
          to_ruby(expr, quoted: true, use_result: true)
        in [(:eq | :eql | :equal | :and | :or | :==), expr]
          to_ruby(expr, use_result: use_result)
        in [:eq => operator, left, right]
          receiver = to_ruby(left, use_result: use_result)
          arg      = to_ruby(right, use_result: use_result)
          CompiledCode.new(
            "#{receiver}.equal?(#{arg})",
            taint: receiver.taint? || arg.taint?,
            affect: receiver.affect? || arg.affect?,
            type: BOOLEAN_TYPE
          )
        in [(:< | :> | :<= | :>= | :eql | :equal | :and | :or | :==) => operator, left, right]
          left_code = to_ruby(left, use_result: use_result)
          right_code = to_ruby(right, use_result: use_result)
          CompiledCode.new(
            [left_code, OPERATOR_DICT[operator], right_code].join(' '),
            taint: left_code.taint? || right_code.taint?,
            affect: left_code.affect? || right_code.affect?,
            type: BOOLEAN_TYPE,
            priority: OPERATOR_DICT[operator].priority
          )
        in [(:< | :> | :<= | :>= | :eq | :eql | :equal | :==) => operator, *exprs] if exprs.size >= 3
          codes = exprs.map { to_ruby(_1, use_result: true) }
          args = codes.join(', ')
          CompiledCode.new(
            "[#{args}].each_cons(2, &:#{OPERATOR_DICT[operator]})",
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: BOOLEAN_TYPE
          )
        in [(:and | :or | :+ | :- | :* | :/) => operator, *exprs] if exprs.size >= 2
          codes = exprs.map { to_ruby(_1, use_result: true) }
          operator = OPERATOR_DICT[operator]
          CompiledCode.new(
            codes.join(" #{operator} "),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: ANY
          )
        in [:not, expr]
          code = to_ruby(expanded[1], use_result: use_result)
          priority_breaking = code.priority > OPERATOR_NOT.priority
          CompiledCode.new(
            priority_breaking ? "!(#{code})" : "!#{code}",
            taint: code.taint?,
            affect: code.affect?,
            type: BOOLEAN_TYPE,
            priority: priority_breaking ? -1 : 2
          )
        in [:progn, *exprs]
          code = progn(exprs, use_result: use_result)
          CompiledCode.new(
            "begin\n#{code.indent}\nend",
            taint: code.taint?,
            affect: code.affect?,
            type: code.type
          )
        in [:if, cond, then_expr]
          cond_code = to_ruby(cond, use_result: use_result)
          then_code = to_ruby(then_expr, use_result: use_result)
          if use_result && cond_code.each_line.size == 1 && then_code.each_line.size == 1
            CompiledCode.new(
              "#{cond_code} && #{then_code}",
              taint: cond_code.taint? || then_code.taint?,
              affect: cond_code.affect? || then_code.affect?,
              type: then_code.type | FALSY_TYPE,
              priority: OPERATOR_LOGICAL_AND.priority
            )
          else
            CompiledCode.new(
              [
                "if #{cond_code}",
                then_code.indent,
                'end'
              ].join("\n"),
              taint: cond_code.taint? || then_code.taint?,
              affect: cond_code.affect? || then_code.affect?,
              type: then_code.type | NIL_TYPE
            )
          end
        in [:if, cond, then_expr, *else_progn, else_result]
          cond_code = to_ruby(cond, use_result: use_result)
          then_code = to_ruby(then_expr, use_result: use_result)
          else_code = [
            *else_progn.map { to_ruby(_1, use_result: false) },
            to_ruby(else_result, use_result: use_result)
          ]
          if else_progn.empty? && then_code.pure? && then_code.type.subset?(TRUE_TYPE)
            if else_code.last.pure? && FALSY_TYPE.intersect?(else_code.last.type)
              CompiledCode.new(
                cond_code,
                taint: cond_code.taint?,
                affect: cond_code.affect?,
                type: LOGICAL_TYPE,
                priority: OPERATOR_LOGICAL_OR
              )
            else
              CompiledCode.new(
                "#{cond_code} || #{else_code.last}",
                taint: cond_code.taint? || else_code.last.taint?,
                affect: cond_code.affect? || else_code.last.affect?,
                type: TRUE_TYPE | else_code.last.type,
                priority: OPERATOR_LOGICAL_OR
              )
            end
          else
            CompiledCode.new(
              [
                "if #{cond_code}",
                then_code.indent,
                'else',
                *else_code.map(&:indent),
                'end'
              ].join("\n"),
              taint: [cond_code, then_code, *else_code].any?(&:taint?),
              affect: [cond_code, then_code, *else_code].any?(&:affect?),
              type: then_code.type | else_code.last.type
            )
          end
        in [Symbol | String => method, _ => receiver]
          receiver_code = to_ruby(receiver)
          CompiledCode.new(
            "#{receiver_code}.#{method}",
            taint: true,
            affect: true
          )
        in [Symbol | String => method, _ => receiver, *args]
          receiver_code = to_ruby(receiver)
          arg_codes = args.map(&method(:to_ruby))
          buf = "#{receiver_code}.#{method}("
          buf += arg_codes.join(', ')
          CompiledCode.new(
            "#{buf})",
            taint: true,
            affect: true
          )
        end
      end
    end
  end
end
