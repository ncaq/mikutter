# -*- coding: utf-8 -*-

module MIKU
  module ToRuby
    STRING_LITERAL_ESCAPE_MAP = {'\\' => '\\\\', "'" => "\\'"}.freeze
    STRING_LITERAL_ESCAPE_MATCHER = Regexp.union(STRING_LITERAL_ESCAPE_MAP.keys).freeze
    OPERATOR_DICT = { :< => "<", :> => ">", :<= => "<=", :>= => ">=", :eql => "==", :equal => "===", :and => "&&", :or => "||", :== => "==", :eq => 'equal?' }.freeze

    class << self
      def indent(code)
        code.each_line.map{|l| "  #{l}"}.join("\n")
      end

      def progn(list, quoted: false, use_result: true)
        if options[:use_result]
          *progn_code, progn_last = list
          [*progn_code.map{|n| to_ruby(n, use_result: false)}, to_ruby(progn_last, use_result: :to_return)].join("\n")
        else
          list.map{|n| to_ruby(n, use_result: false)}.join("\n") end end

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
        when Symbol
          (options[:quoted] ? ":" : "") + "#{expanded.to_s}"
        # when Numeric
        #   expanded.to_s # same else form
        when String
          string_literal(expanded)
        when TrueClass
          'true'
        when FalseClass
          'false'
        when NilClass
          'nil'
        when List
          if options[:quoted]
            '[' + expanded.map{|node| to_ruby(node, quoted: true, use_result: true)}.join(", ") + ']'
          else
            case expanded
            in [:quote, expr]
              to_ruby(expr, quoted: true, use_result: true)
            in [(:eq | :eql | :equal | :and | :or | :==), expr]
              to_ruby(expr, use_result: options[:use_result])
            in [:eq => operator, left, right]
              receiver = to_ruby(left, use_result: options[:use_result])
              arg      = to_ruby(right, use_result: options[:use_result])
              "#{receiver}.equal?(#{arg})"
            in [(:< | :> | :<= | :>= | :eql | :equal | :and | :or | :==) => operator, left, right]
              [
                to_ruby(left, use_result: options[:use_result]),
                OPERATOR_DICT[operator],
                to_ruby(right, use_result: options[:use_result])
              ].join(' ')
            in [(:< | :> | :<= | :>= | :eq | :eql | :equal | :==) => operator, *exprs] if exprs.size >= 3
              args = exprs.map { to_ruby(_1, use_result: true) }.join(', ')
              "[#{args}].each_cons(2, &:#{OPERATOR_DICT[operator]})"
            in [(:and | :or | :+ | :- | :* | :/) => operator, *exprs] if exprs.size >= 2
              operator = OPERATOR_DICT[operator] || operator.to_s
              exprs.map { to_ruby(_1, use_result: true) }.join(" #{operator} ")
            in [:not, expr]
              "!(#{to_ruby(expanded[1], use_result: options[:use_result])})"
            in [:progn, *exprs]
              "begin\n" + indent(progn(exprs, use_result: options[:use_result])) + "\nend\n"
            in [:if, cond, then_expr]
              cond_code = to_ruby(cond, use_result: options[:use_result])
              then_code = to_ruby(then_expr, use_result: options[:use_result])
              if options[:use_result] && cond_code.each_line.size == 1 && then_code.each_line.size == 1
                "#{cond_code} && #{then_code}"
              else
                [
                  "if #{cond_code}",
                  indent(then_code),
                  'end'
                ].join("\n")
              end
            in [:if, cond, then_expr, *else_exprs]
              cond_code = to_ruby(cond, use_result: options[:use_result])
              then_code = to_ruby(then_expr, use_result: options[:use_result])
              *else_progn, else_result = else_exprs
              else_code = [
                *else_progn.map { to_ruby(_1, use_result: false) },
                to_ruby(else_result, use_result: options[:use_result])
              ]
              [
                "if #{cond_code}",
                indent(then_code),
                'else',
                *else_code.map(&method(:indent)),
                'end'
              ].join("\n")
            in [Symbol | String => method, _ => receiver]
              "#{to_ruby(receiver)}.#{method}"
            in [Symbol | String => method, _ => receiver, *args]
              buf = "#{to_ruby(receiver)}.#{method}("
              buf += args.map(&method(:to_ruby)).join(', ')
              "#{buf})"
            end
          end
        else
          expanded.to_s
        end
      end

      def string_literal(str)
        escaped = str.gsub(STRING_LITERAL_ESCAPE_MATCHER, STRING_LITERAL_ESCAPE_MAP)
        "'#{escaped}'"
      end
    end
  end
end
