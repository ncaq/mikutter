# -*- coding: utf-8 -*-

require_relative 'to_ruby/compiled_code'
require_relative 'to_ruby/operator'
require_relative 'to_ruby/generic_proc'

module MIKU
  module ToRuby
    STRING_LITERAL_ESCAPE_MAP = { '\\' => '\\\\', "'" => "\\'" }.freeze
    STRING_LITERAL_ESCAPE_MATCHER = Regexp.union(STRING_LITERAL_ESCAPE_MAP.keys).freeze
    OPERATOR_DICT = { # MIKU_FUNCNAME => Operator
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
      :/ => OPERATOR_DIVISION
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
      def to_ruby(sexp, options={ quoted: false, use_result: true })
        expanded = sexp
        case expanded
        when :true, true # rubocop:disable Lint/BooleanSymbol
          CompiledCode.new('true', taint: false, affect: false, type: TRUE_TYPE)
        when :false, false # rubocop:disable Lint/BooleanSymbol
          CompiledCode.new('false', taint: false, affect: false, type: FALSE_TYPE)
        when :nil, nil
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
            codes = expanded.map { |node| to_ruby(node, quoted: true, use_result: true) }
            CompiledCode.new(
              "[#{codes.join(', ')}]",
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
          "'#{escaped}'",
          taint: false,
          affect: false,
          type: Type.new(String, freeze: true)
        )
      end

      def miracle_defarg(argsym)
        case argsym
        in []
          ''
        in [*args, [:rest, Symbol => rest]]
          x = +'('
          x << args.join(', ')
          "#{x}, *#{rest})".freeze
        in [*args]
          "(#{args.join(', ')})"
        end
      end

      def ife(cond_expr, then_expr, *else_progn_expr, else_result_expr, quoted: false, use_result: true)
        pattern = [
          to_ruby(cond_expr, use_result: true),
          to_ruby(then_expr, use_result: use_result),
          *else_progn_expr.map { to_ruby(_1, use_result: false) },
          to_ruby(else_result_expr, use_result: use_result)
        ]
        case pattern
        in [code, {pure: true, type: TRUE_TYPE}, {pure: true, type: FALSY_TYPE}]
          code
        in [cond_code, then_code, {pure: true, type: FALSY_TYPE}] => codes
          cond_code.attach_paren if cond_code.priority > OPERATOR_LOGICAL_AND.priority
          then_code.attach_paren if then_code.priority > OPERATOR_LOGICAL_AND.priority
          CompiledCode.new(
            "#{cond_code} && #{then_code}",
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: then_code.type | NIL_TYPE,
            priority: [cond_code.priority, then_code.priority, OPERATOR_LOGICAL_AND].max
          )
        in [cond_code, {pure: true, type: TRUE_TYPE}, else_code]
          cond_code.attach_paren if cond_code.priority > OPERATOR_LOGICAL_OR.priority
          else_code.attach_paren if else_code.priority > OPERATOR_LOGICAL_OR.priority
          CompiledCode.new(
            "#{cond_code} || #{else_code}",
            taint: cond_code.taint? || else_code.taint?,
            affect: cond_code.affect? || else_code.affect?,
            type: cond_code.type | else_code.type,
            priority: [cond_code.priority, else_code.priority, OPERATOR_LOGICAL_OR].max
          )
        in [cond_code, then_code, *else_code] => codes
          CompiledCode.new(
            [
              "if #{cond_code}",
              then_code.indent,
              'else',
              *else_code.map(&:indent),
              'end'
            ].join("\n"),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: then_code.type | else_code.last.type
          )
        end
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
          operator = OPERATOR_DICT[operator]
          left_code = to_ruby(left, use_result: true)
          right_code = to_ruby(right, use_result: true)
          [left_code, right_code].select { _1.priority > operator.priority }.map(&:attach_paren)
          CompiledCode.new(
            [left_code, operator, right_code].join(' '),
            taint: left_code.taint? || right_code.taint?,
            affect: left_code.affect? || right_code.affect?,
            type: BOOLEAN_TYPE,
            priority: [left_code, right_code, operator].map(&:priority).max
          )
        in [(:< | :> | :<= | :>= | :eq | :eql | :equal | :==) => operator, *exprs] if exprs.size >= 3
          codes = exprs.map { to_ruby(_1, use_result: true) }
          args = codes.join(', ')
          CompiledCode.new(
            "[#{args}].each_cons(2).inject(&:#{OPERATOR_DICT[operator]})",
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: BOOLEAN_TYPE
          )
        in [(:and | :or | :+ | :- | :* | :/) => operator, *exprs] if exprs.size >= 2
          codes = exprs.map { to_ruby(_1, use_result: true) }
          operator = OPERATOR_DICT[operator]
          codes.select { _1.priority > operator.priority }.map(&:attach_paren)
          CompiledCode.new(
            codes.join(" #{operator} "),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: ANY,
            priority: [*codes.map(&:priority), operator.priority].max
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
          ife(cond, then_expr, false, use_result: use_result)
        in [:if, cond, then_expr, *else_progn, else_result]
          ife(cond, then_expr, *else_progn, else_result, use_result: use_result)
        in [:lambda, [*argsym], body]
          return_code = to_ruby(body, use_result: :to_return)
          CompiledCode.new(
            "->#{miracle_defarg(argsym)} { #{return_code} }",
            taint: return_code.taint?,
            affect: return_code.affect?,
            type: Type.new(GenericProc.new(return_code.type))
          )
        in [:lambda, [*argsym], *body, return_body] if body.size >= 2
          body_codes = body.map { to_ruby(_1, use_result: false) }
          return_code = to_ruby(return_body, use_result: :to_return)
          codes = [*body_codes, return_code]
          CompiledCode.new(
            [
              "->#{miracle_defarg(argsym)} do",
              *codes.map(&:indent),
              'end'
            ].join("\n"),
            taint: codes.any?(&:taint?),
            affect: codes.any?(&:affect?),
            type: Type.new(GenericProc.new(return_code.type))
          )
        in [Symbol | String => method, _ => receiver]
          receiver_code = to_ruby(receiver, use_result: true)
          CompiledCode.new(
            "#{receiver_code}.#{method}",
            taint: true,
            affect: true
          )
        in [Symbol | String => method, _ => receiver, *args]
          receiver_code = to_ruby(receiver, use_result: true)
          arg_codes = args.map(&method(:to_ruby))
          buf = "#{receiver_code}.#{method}("
          buf += arg_codes.join(', ')
          CompiledCode.new(
            "#{buf})",
            taint: true,
            affect: true
          )
        in [func, *args]
          func = to_ruby(func, use_result: true).attach_paren
          arg_codes = args.map { to_ruby(_1, use_result: true) }
          arg_single_line = arg_codes.all?(&:single_line?)
          case func.type.types.to_a
          in [GenericProc => proc_type]
            if arg_single_line
              CompiledCode.new(
                "#{func}.(#{arg_codes.join(', ')})",
                taint: func.taint? || arg_codes.any?(&:taint?),
                affect: func.affect? || arg_codes.any?(&:affect?),
                type: proc_type.return_type
              )
            else
              [
                "#{func}.(",
                *arg_codes.map { "  #{_1}," },
                ')'
              ].join("\n")
            end
          else
            CompiledCode.new(
              [
                "#{func}.then do |__func|",
                '  if __func.respond_to?(:call)',
                *if arg_single_line
                   "    __func.(#{arg_codes.join(', ')})"
                 else
                   [
                     '    __func.(',
                     *arg_codes.map { "      #{_1}," },
                     '    )'
                   ]
                 end,
                '  elsif __func.is_a?(Symbol)',
                *if arg_codes.first.single_line?
                   "    __receiver = #{arg_codes.first}"
                 else
                   ac1, *acrest = arg_codes.first.each_line.map(&:chomp)
                   [
                     "    __receiver = #{ac1}",
                     *acrest.map { "      #{_1}" }
                   ]
                 end,
                '    if __receiver.respond_to?(__func)',
                *if arg_single_line
                   "      __receiver.public_send(__func, #{arg_codes.join(', ')})"
                 else
                   [
                     '      __receiver.(',
                     '        __func,',
                     *arg_codes.map { "        #{_1}," },
                     '      )'
                   ]
                 end,
                '    end',
                '  end',
                'end'
              ].join("\n"),
              taint: func.taint? || arg_codes.any?(&:taint?),
              affect: func.affect? || arg_codes.any?(&:affect?)
            )
          end
        end
      end
    end
  end
end
