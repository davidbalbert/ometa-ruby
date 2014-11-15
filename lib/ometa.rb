=begin
CURRENT STATUS

SimplerMath doesn't work.

It works for num, but not for expr

class SimplerMath < OMeta::Parser
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

class SomeMath < OMeta::Parser
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

class A < OMeta::Parser
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

module OMeta
  class OMetaError < StandardError; end

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

  FAIL = Object.new

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
        new.match(input, target)
      end

      alias =~ match
      alias === match
    end

    attr_reader :input_after_match

    def initialize
      @memo_table = MemoizationTable.new
    end

    def match(input, target = self.class.target)
      if target.nil? && self.class.target.nil?
        raise ParseError, "Target cannot be nil. Either specify a target or set a default one using the `target' class method."
      elsif target.nil?
        raise ParseError, "Target cannot be nil."
      end

      result, @input_after_match = _apply(input, target)

      if result == FAIL
        nil
      else
        result
      end
    end

    def _apply(input, rule_name, *args)
      if @memo_table.include?(rule_name, args, input)
        return @memo_table[rule_name, args, input]
      end

      original_input, remaining_input = input
      longest_match_size = -1

      @memo_table[rule_name, args, original_input] = [FAIL, input] # start by memoizing a failure

      loop do
        rule = send(rule_name, *args)

        unless rule.is_a?(Proc)
          raise OMetaError, "`#{rule_name}' must return a Proc"
        end

        res, remaining_input = rule.call(original_input)

        match_size = original_input.size - remaining_input.size

        break if res == FAIL || match_size <= longest_match_size

        longest_match_size = match_size

        @memo_table[rule_name, args, original_input] = [res, remaining_input]
      end

      @memo_table[rule_name, args, original_input]
    end

    def anything
      ->(input) do
        unless input.empty?
          [input[0], input[1..-1]]
        else
          [FAIL, input]
        end
      end
    end

    def end
      ->(input) do
        _not(input, ->(input) { _apply(input, :anything) })
      end
    end

    def empty
      ->(input) { [true, input] }
    end

    def char
      ->(input) do
        c, remaining_input = _apply(input, :anything)

        if c.is_a?(String) && c.size == 1
          [c, remaining_input]
        else
          [FAIL, input]
        end
      end
    end

    def exactly(c)
      ->(input) do
        res, remaining_input = _apply(input, :anything)

        if c == res
          [res, remaining_input]
        else
          [FAIL, input]
        end
      end
    end

    def sequence(cs)
      ->(input) do
        remaining_input = input

        cs.each_char do |c|
          res, remaining_input = _apply(remaining_input, :exactly, c)

          if res == FAIL
            return [FAIL, input]
          end
        end

        [cs, remaining_input]
      end
    end

    def literal(s)
      ->(input) do
        _apply(input, :sequence, s)
      end
    end

    def _not(input, rule)
      original_input = input

      res, _ = rule.call(input)

      if res == FAIL
        [true, input]
      else
        [FAIL, input]
      end
    end

    def _lookahead(input, rule)
      _not(input, ->(input) { _not(input, rule) })
    end

    def _or(input, *rules)
      rules.each do |rule|
        res, remaining_input = rule.call(input)

        return [res, remaining_input] unless res == FAIL
      end

      [FAIL, input]
    end

    def _zero_or_more(input, rule)
      results = []
      last_good_input = input

      loop do
        res, remaining_input = rule.call(input)

        break if res == FAIL

        last_good_input = remaining_input

        results << res
      end

      [results, last_good_input]
    end

    def _one_or_more(input, rule)
      res, remaining_input = rule.call(input)

      if res == FAIL
        return [FAIL, input]
      end

      zom_res, remaining_input = _zero_or_more(remaining_input, rule)
      [[res] + zom_res, remaining_input]
    end
  end
end
