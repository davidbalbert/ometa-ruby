require "peg/version"

module Peg
  class Literal
    def initialize(s)
      @s = s
    end

    def match(input)
      if input.start_with? @s
        input[@s.size..-1]
      end
    end
  end

  class Sequence
    def initialize(*rules)
      @rules = rules
    end

    def match(input)
      @rules.reduce(input) do |input, rule|
        if input
          rule.match input
        else
          input
        end
      end
    end
  end

  class OrderedChoice
    def initialize(*rules)
      @rules = rules
    end

    def match(input)
      @rules.each do |rule|
        res = rule.match(input)
        return res if res
      end

      nil
    end
  end

  class Any
    def match(input)
      unless input.empty?
        input[1..-1]
      end
    end
  end

  class Not
    def initialize(rule)
      @rule = rule
    end

    def match(input)
      unless @rule.match(input)
        input
      end
    end
  end

  class Lookahead
    def initialize(rule)
      @rule = Not.new(Not.new(rule))
    end

    def match(input)
      @rule.match(input)
    end
  end

  class Maybe
    def initialize(rule)
      @rule = rule
    end

    def match(input)
      @rule.match(input) || input
    end
  end

  class ZeroOrMore
    def initialize(rule)
      @rule = rule
    end

    def match(input)
      until input.nil?
        old = input
        input = @rule.match(input)
      end

      old
    end
  end

  class OneOrMore
    def initialize(rule)
      @rule = Sequence.new(rule, ZeroOrMore.new(rule))
    end

    def match(input)
      @rule.match(input)
    end
  end

  class Grouping
    def initialize(rule)
      @rule = rule
    end

    def match(input)
      @rule.match(input)
    end
  end

  class Characters
    def initialize(*chars)
      @rule = OrderedChoice.new(*chars.map { |c| Literal.new(c) })
    end

    def match(input)
      @rule.match(input)
    end
  end

  class Grammar
    def self.rule(name, body)
      case body
      when Symbol
        rule(name, [[body, body]])
      when Array
        # do actual stuff here
      else
        rule(name, [body])
      end
    end
  end
end

class Simple < Peg::Grammar
  rule :top, [[Any.new, :x], "b", [Any.new, :y]] { |x:, y:| x + y }
end

Simple.new.match("abc") # => "ac"
Simple.new.match("abcd") # => "ac"
Simple.new.match("ab") # => nil

class Addition < Peg::Grammar
  rule :expr, [:num, "+", :expr] { |num:, expr:| num + expr }
  rule :expr, :num

  rule :num, [[one_or_more(:digit), :digits]] { |digits:| digits.join.to_i }

  rule :digit Characters.new(%w<0 1 2 3 4 5 6 7 8 9>)
end

if __FILE__ == $0
  require 'minitest/autorun'

  module Peg
    class PegTest < Minitest::Test
      def test_string_rule
        assert_equal "", Literal.new("hello").match("hello")
        assert_equal " world", Literal.new("hello").match("hello world")
        assert_nil Literal.new("hello").match("goodbye")
        assert_nil Literal.new("hello world").match("hello")
      end

      def test_sequence_rule
        rule = Sequence.new(Literal.new("a"), Literal.new("b"))
        assert_equal "", rule.match("ab")
        assert_nil rule.match("ac")
      end

      def test_ordered_choice
        rule = OrderedChoice.new(Literal.new("a"), Literal.new("b"), Literal.new("ab"))
        assert_equal "", rule.match("a")
        assert_equal "", rule.match("b")
        assert_equal "b", rule.match("ab")
        assert_equal "bc", rule.match("abc")
        assert_nil rule.match("cde")
      end

      def test_any
        assert_equal "", Any.new.match("a")
        assert_nil Any.new.match("")
      end

      def test_not
        assert_equal "", Not.new(Any.new).match("")
        assert_equal "a", Not.new(Not.new(Any.new)).match("a")
      end

      def test_lookahead
        rule = Lookahead.new(Literal.new("ab"))
        assert_equal "abc", rule.match("abc")
        assert_nil rule.match("bbc")
      end

      def test_maybe
        rule = Maybe.new(Literal.new("a"))
        assert_equal "", rule.match("a")
        assert_equal "b", rule.match("b")
      end

      def test_zero_or_more
        rule = ZeroOrMore.new(Literal.new("a"))
        assert_equal "", rule.match("")
        assert_equal "", rule.match("a")
        assert_equal "", rule.match("aa")
      end

      def test_one_or_more
        rule = OneOrMore.new(Literal.new("a"))
        assert_nil rule.match("")
        assert_equal "", rule.match("a")
        assert_equal "", rule.match("aa")
      end

      def test_grouping
        assert_equal "", Grouping.new(Literal.new("abc")).match("abc")
      end

      def test_chars
        rule = Characters.new(?a, ?b, ?c)
        assert_equal "", rule.match(?a)
        assert_equal "", rule.match(?b)
        assert_equal "", rule.match(?c)
        assert_nil rule.match(?d)
      end
    end
  end
end
