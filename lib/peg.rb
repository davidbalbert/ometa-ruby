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

  class MatchData
    attr_reader :bindings
    attr_accessor :value, :pos

    module StringConversion
      refine String do
        def to_match_data
          MatchData.new(self)
        end
      end
    end

    def initialize(input, pos = 0)
      @input = input
      @pos = pos
      @last_match = nil
      @bindings = {}
    end

    def clone_with_progress
      self.class.new(@input, @pos)
    end

    def [](name)
      @bindings[name]
    end

    def input
      @input[@pos..-1]
    end

    def matched_input
      @input[0...@pos]
    end

    def advance(size)
      @last_match = @input[pos...(pos + size)]
      @pos += size

      self
    end

    def clear_last_match
      @last_match = nil
    end

    def capture_last_match(name)
      if @last_match
        @bindings[name] = @last_match
      end
    end

    def to_match_data
      self
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

    using MatchData::StringConversion

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
      match_data = input.to_match_data

      if action
        old_bindings = match_data
        match_data = match_data.clone_with_progress
      end

      match_data.clear_last_match
      match_data = check_match(match_data)

      return nil unless match_data

      if name
        match_data.capture_last_match(name)
      end

      if action && match_data
        match_data.value = action.call(**match_data.bindings)
      end

      if old_bindings
        old_bindings.value = match_data.value
        old_bindings.pos = match_data.pos

        old_bindings
      else
        match_data
      end
    end

    alias =~ match
    alias === match
  end

  class Literal < Rule
    def initialize(s, **options)
      super(**options)
      @s = s
    end

    def check_match(match_data)
      if match_data.input.start_with? @s
        match_data.advance(@s.size)
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

    def check_match(match_data)
      @rules.reduce(match_data) do |md, rule|
        if md
          rule.match md
        else
          md
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

    def check_match(match_data)
      @rules.each do |rule|
        res = rule.match(match_data)
        return res if res
      end

      nil
    end
  end

  class Any < Rule
    def check_match(match_data)
      unless match_data.input.empty?
        match_data.advance(1)
      end
    end
  end

  class Not < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(match_data)
      unless @rule.match(match_data)
        match_data
      end
    end
  end

  class Lookahead < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = Not.new(Not.new(rule))
    end

    def check_match(match_data)
      @rule.match(match_data)
    end
  end

  class Maybe < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(match_data)
      @rule.match(match_data) || match_data
    end
  end

  class ZeroOrMore < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(match_data)
      until match_data.nil?
        old = match_data
        match_data = @rule.match(match_data)
      end

      old
    end
  end

  class OneOrMore < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = Sequence.new(rule, ZeroOrMore.new(rule))
    end

    def check_match(match_data)
      @rule.match(match_data)
    end
  end

  class Grouping < Rule
    def initialize(rule, **options)
      super(**options)
      @rule = rule
    end

    def check_match(match_data)
      @rule.match(match_data)
    end
  end

  class Characters < Rule
    def initialize(*chars, **options)
      super(**options)
      @rule = OrderedChoice.new(*chars.map { |c| Literal.new(c) })
    end

    def check_match(match_data)
      @rule.match(match_data)
    end
  end

  class Call < Rule
    def initialize(grammar, target, **options)
      super(**options)
      @grammar = grammar
      @target = target
    end

    def check_match(match_data)
      @grammar[@target].match(match_data)
    end
  end

  class Grammar
    class << self
      def rule(name, body, &action)
        @rules  ||= Hash.new { NullRule.new }
        @target ||= name

        @rules[name] = @rules[name] | Rule.parse(self, body, action)
      end

      def match(input)
        md = @rules[@target].match(input)

        if md
          md.value || md.matched_input
        end
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
