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

    alias =~ match
    alias === match
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

      alias =~ match
      alias === match

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
