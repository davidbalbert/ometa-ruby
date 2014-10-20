=begin
CURRENT STATUS

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

class ApplyTest < Peg::Parser
  target :a
  
  def a
    -> { _apply(:b) }
  end
  
  def b
    -> { _apply(:literal, "hello") }
  end
end

class SimpleTest < Peg::Parser
  target :hello
  
  def hello
    -> { _apply(:literal, "hello") }
  end
end

class Anything < Peg::Parser
  target :whatever
  
  def whatever
    -> { _apply(:anything) }
  end
end

Anything.match "a" => "a"
Antyhing.match "ab" => nil # this is wrong
=end


module Peg
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
      puts "_apply(#{rule_name.inspect}, #{args.inspect})"

      if @memo_table.include?(rule_name, args, @input)
        return @memo_table[rule_name, args, @input]
      end

      original_input = @input
      longest_match_size = 0
      res = nil

      @memo_table[rule_name, args, original_input] = nil # start by memoizing a failure

      loop do
        p [rule_name, @input, @memo_table]
        res = _call_rule(send(rule_name, *args))

        match_size = original_input.size - @input.size

        break if match_size <= longest_match_size

        longest_match_size = match_size
        @input = original_input

        @memo_table[rule_name, args, original_input] = res
      end

      if res
        @input = res

        res
      else
        throw(:match_failed, nil)
      end
    end

    def anything
      lambda do
        unless @input.empty?
          puts "returning #{@input[0]}"
          @input[0]
        else
          throw(:match_failed, nil)
        end
      end
    end

    def exactly(c)
      lambda do
        if c == _apply(:anything)
          c
        else
          throw(:match_failed, nil)
        end
      end
    end

    def sequence(cs)
      lambda do
        cs.each_char do |c|
          _apply(:exactly, c)
        end

        cs
      end
    end

    def literal(s)
      lambda do
        _apply(:sequence, s)
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

    def _call_rule(rule)
      catch :match_failed do
        rule.call
      end
    end
  end
end
