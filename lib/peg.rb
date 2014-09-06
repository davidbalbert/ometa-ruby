require "peg/version"

module Peg
  class ParseError < StandardError; end

  class NullRule
    def |(rule)
      rule
    end

    def <<(rule)
      rule
    end

    def match(input)
      nil
    end
  end

  class Rule
    class << self
      def parse(grammar, body, action)
        rule = NullRule.new

        if body.empty?
          raise ParseError, "Rule body cannot be empty."
        end

        body.each do |item|
          if item.is_a?(Array)
            rule = rule << process(grammar, item[0], name: item[1])
          else
            rule = rule << process(grammar, item)
          end
        end

        rule.action = action

        rule
      end

      private

      def process(grammar, item, **options)
        case item
        when String
          Literal.new(item, **options)
        when Symbol
          Call.new(grammar, item, **options)
        else
          item.name = options[:name]

          item
        end
      end
    end

    attr_reader :name
    attr_accessor :name, :action

    def initialize(name: name, action: action)
      @name = name
      @action = action
    end

    def <<(rule)
      Sequence.new(self, rule)
    end

    def |(rule)
      OrderedChoice.new(self, rule)
    end

    def match(input)
      res = check_match(input)

      if action && res
        action.call
      end

      res
    end
  end

  class Literal < Rule
    def initialize(s, **options)
      super(**options)
      @s = s
    end

    def check_match(input)
      if input.start_with? @s
        input[@s.size..-1]
      end
    end
  end

  class Sequence < Rule
    def initialize(*rules, **options)
      super(**options)
      @rules = rules
    end

    def <<(rule)
      @rules << rule

      self
    end

    def check_match(input)
      @rules.reduce(input) do |input, rule|
        if input
          rule.match input
        else
          input
        end
      end
    end
  end

  class OrderedChoice < Rule
    def initialize(*rules, **options)
      super(**options)
      @rules = rules
    end

    def |(rule)
      @rules << rule

      self
    end

    def check_match(input)
      @rules.each do |rule|
        res = rule.match(input)
        return res if res
      end

      nil
    end
  end

  class Any < Rule
    def check_match(input)
      unless input.empty?
        input[1..-1]
      end
    end
  end

  class Not < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(input)
      unless @rule.match(input)
        input
      end
    end
  end

  class Lookahead < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = Not.new(Not.new(rule))
    end

    def check_match(input)
      @rule.match(input)
    end
  end

  class Maybe < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(input)
      @rule.match(input) || input
    end
  end

  class ZeroOrMore < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(input)
      until input.nil?
        old = input
        input = @rule.match(input)
      end

      old
    end
  end

  class OneOrMore < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = Sequence.new(rule, ZeroOrMore.new(rule))
    end

    def check_match(input)
      @rule.match(input)
    end
  end

  class Grouping < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(input)
      @rule.match(input)
    end
  end

  class Characters < Rule
    def initialize(*chars, **options)
      super(**options)
      @rule = OrderedChoice.new(*chars.map { |c| Literal.new(c) })
    end

    def check_match(input)
      @rule.match(input)
    end
  end

  class Call < Rule
    def initialize(grammar, target, **options)
      super(**options)
      @grammar = grammar
      @target = target
    end

    def check_match(input)
      @grammar[@target].match(input)
    end
  end

  class Grammar
    class << self
      def rule(name, *body, &action)
        @rules  ||= Hash.new { NullRule.new }
        @target ||= name

        @rules[name] = @rules[name] | Rule.parse(self, body, action)
      end

      def match(input)
        @rules[@target].match(input)
      end

      def [](name)
        @rules[name]
      end
    end
  end
end

=begin
class Simple < Peg::Grammar
  rule :top, [[Any.new, :x], "b", [Any.new, :y]] { |x:, y:| x + y }
end

Simple.new.match("abc") # => "ac"
Simple.new.match("abcd") # => "ac"
Simple.new.match("ab") # => nil

class Addition < Peg::Grammar
  rule :expr, [[:num, :n], "+", [:expr, :e]] { |n:, e:| n + e }
  rule :expr, :num

  rule :num, [[one_or_more(:digit), :digits]] { |digits:| digits.join.to_i }

  rule :digit Characters.new(%w<0 1 2 3 4 5 6 7 8 9>)
end
=end

#class Simple < Peg::Grammar
  #rule :top, [Peg::Any.new, :x], "b", [Peg::Any.new, :y] { |x:, y:| x + y }
#end

#Simple.match("abc") # => "ac"

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

      def test_sequence_peg
        peg = Sequence.new(Literal.new("a"), Literal.new("b"))
        assert_equal "", peg.match("ab")
        assert_nil peg.match("ac")
      end

      def test_ordered_choice
        peg = OrderedChoice.new(Literal.new("a"), Literal.new("b"), Literal.new("ab"))
        assert_equal "", peg.match("a")
        assert_equal "", peg.match("b")
        assert_equal "b", peg.match("ab")
        assert_equal "bc", peg.match("abc")
        assert_nil peg.match("cde")
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
        peg = Lookahead.new(Literal.new("ab"))
        assert_equal "abc", peg.match("abc")
        assert_nil peg.match("bbc")
      end

      def test_maybe
        peg = Maybe.new(Literal.new("a"))
        assert_equal "", peg.match("a")
        assert_equal "b", peg.match("b")
      end

      def test_zero_or_more
        peg = ZeroOrMore.new(Literal.new("a"))
        assert_equal "", peg.match("")
        assert_equal "", peg.match("a")
        assert_equal "", peg.match("aa")
      end

      def test_one_or_more
        peg = OneOrMore.new(Literal.new("a"))
        assert_nil peg.match("")
        assert_equal "", peg.match("a")
        assert_equal "", peg.match("aa")
      end

      def test_grouping
        assert_equal "", Grouping.new(Literal.new("abc")).match("abc")
      end

      def test_chars
        peg = Characters.new(?a, ?b, ?c)
        assert_equal "", peg.match(?a)
        assert_equal "", peg.match(?b)
        assert_equal "", peg.match(?c)
        assert_nil peg.match(?d)
      end

      def test_grammar
        g = Class.new(Peg::Grammar) do
          rule :top, ["hello", :x], "world"
        end

        assert_equal "", g.match("helloworld")
        assert_equal "foo", g.match("helloworldfoo")
        assert_nil g.match("hello")
      end
    end
  end
end
