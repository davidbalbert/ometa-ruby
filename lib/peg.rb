=begin
CURRENT STATUS

SimplerMath doesn't work.

It works for num, but not for expr

class SimplerMath < Peg::Parser
  target :expr

  def expr
    -> do
      _or(
        -> do
          e = _apply(:expr)
          _apply(:literal, "+")
          n = _apply(:num)

          [:add, e, n]
        end,
        -> do
          _apply(:num)
        end
      )
    end
  end

  def num
    -> do
      _apply(:anything)
    end
  end
end

class SomeMath < Peg::Parser
  target :expr

  def expr
    -> do
      _or(
        -> do
          e = _apply(:expr)
          _apply(:literal, "+")
          n = _apply(:num)

          [:add, e, n]
        end,
        -> do
          _apply(:num)
        end
      )
    end
  end

  def num
    -> do
      digits = _one_or_more(-> { _apply(:digit) })

      digits.join.to_i
    end
  end

  def digit
    -> do
      c = _apply(:char)
      _pred(("0".."9").include?(c))

      c
    end
  end
end

class A < Peg::Parser
  target :as

  def as
    lambda do
      _or(
        lambda {
          as = _apply(:as)
          a = _apply(:literal, "a")

          as + a
        },
        lambda {
          _apply(:literal, "a")
        }
      )
    end
  end
end

=end


module Peg
  class PegError < StandardError; end

  class MemoizationTable
    def initialize
      @t = {}
    end

    def [](rule, args, input)
      @t[[rule, args, input]]
    end

    def []=(rule, args, input, result)
      @t[[rule, args, input]] = result
    end

    def include?(rule, args, input)
      @t.include?([rule, args, input])
    end

    def inspect
      @t.inspect
    end
  end

  class Parser
    class << self
      def target(target = nil)
        if target
          @target = target
        else
          @target
        end
      end

      def match(input, target = @target)
        new(input).match(target)
      end

      alias =~ match
      alias === match
    end

    def initialize(input)
      @input = input
      @memo_table = MemoizationTable.new
    end

    def match(target = nil)
      if target.nil? && self.class.target.nil?
        raise ParseError, "Target cannot be nil. Either specify a target or set a default one using the `target' class method."
      elsif target.nil?
        raise ParseError, "Target cannot be nil."
      end

      catch :match_failed do
        _apply(target)
      end
    end

    def _apply(rule_name, *args)
      if @memo_table.include?(rule_name, args, @input)
        res, remaining_input = @memo_table[rule_name, args, @input]

        if res
          @input = remaining_input

          return res
        else
          throw(:match_failed, nil)
        end
      end

      original_input, remaining_input = @input
      longest_match_size = 0
      res = nil

      @memo_table[rule_name, args, original_input] = [nil, @input] # start by memoizing a failure

      loop do
        rule = send(rule_name, *args)

        unless rule.is_a?(Proc)
          raise PegError, "`#{rule_name}' must return a Proc"
        end

        res = _call_rule(rule)

        remaining_input = @input

        match_size = original_input.size - @input.size

        break if match_size <= longest_match_size

        longest_match_size = match_size
        @input = original_input

        @memo_table[rule_name, args, original_input] = [res, remaining_input]
      end

      if res
        @input = remaining_input

        res
      else
        throw(:match_failed, nil)
      end
    end

    def anything
      ->  do
        unless @input.empty?
          c = @input[0]
          @input = @input[1..-1]

          c
        else
          throw(:match_failed, nil)
        end
      end
    end

    def end
      -> do
        _not(-> { _apply(:anything) })
      end
    end

    def empty
      -> { true }
    end

    def char
      -> do
        c = _apply(:anything)
        _pred(c.is_a?(String))

        c
      end
    end

    def exactly(c)
      ->  do
        if c == _apply(:anything)
          c
        else
          throw(:match_failed, nil)
        end
      end
    end

    def sequence(cs)
      ->  do
        cs.each_char do |c|
          _apply(:exactly, c)
        end

        cs
      end
    end

    def literal(s)
      ->  do
        _apply(:sequence, s)
      end
    end

    def _not(rule)
      original_input = @input

      res = _call_rule(rule)

      if res.nil?
        @input = original_input
        true
      else
        throw(:match_failed, nil)
      end
    end

    def _lookahead(rule)
      _not(-> { _not(rule) })
    end

    def _pred(expr)
      if expr
        true
      else
        throw(:match_failed, nil)
      end
    end

    def _or(*rules)
      original_input = @input
      res = nil

      rules.each do |rule|
        res = _call_rule(rule)

        return res if res

        @input = original_input
      end

      throw(:match_failed, nil)
    end

    def _zero_or_more(rule)
      results = []

      loop do
        res = _call_rule(rule)

        break unless res

        results << res
      end

      results
    end

    def _one_or_more(rule)
      res = _call_rule(rule)

      if res.nil?
        throw(:match_failed, nil)
      end

      [res] + _zero_or_more(rule)
    end

    def _call_rule(rule)
      catch :match_failed do
        rule.call
      end
    end
  end
end
