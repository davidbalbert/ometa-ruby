require "peg/version"

module Peg
  class ParseError < StandardError; end

  class Rule
    attr_accessor :action, :name
    attr_reader :value

    def initialize(name: nil, &action)
      @name = name
      @action = action
    end

    def bindings
      if @name && @value
        {@name => @value}
      else
        {}
      end
    end

    def =~(other)
      match(other)
    end

    def ===(other)
      match(other)
    end
  end

  class Literal < Rule
    def initialize(s, **options, &action)
      super(**options, &action)
      @s = s
      @value = nil
    end

    def match(g)
      return nil unless g.input.start_with?(@s)

      g.advance(@s.size)
      @value = @s

      if @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class Sequence < Rule
    def initialize(*rules, **options, &action)
      super(**options, &action)
      @rules = rules
      @value = nil
    end

    def match(g)
      @rules.each do |rule|
        @value = rule.match(g)

        return nil unless @value
      end

      if @action
        @value = @action.call(**bindings_of_children)
      end

      @value
    end

    private

    def bindings_of_children
      if @value
        @rules.map(&:bindings).reduce(:merge)
      else
        {}
      end
    end
  end

  class OrderedChoice < Rule
    def initialize(*rules, **options, &action)
      super(**options, &action)
      @rules = rules
      @value = nil
    end

    def match(g)
      @rules.each do |rule|
        @value = rule.match(g)

        if @value
          @matched_rule = rule
          break
        end
      end

      if @value && @action
        @value = @action.call(**bindings)
      end

      @value
    end

    private

    def bindings_of_children
      if @value
        @matched_rule.bindings
      else
        {}
      end
    end
  end

  class Any < Rule
    def initialize(**options, &action)
      super(**options, &action)
      @value = nil
    end

    def match(g)
      unless g.input.empty?
        @value = g.input[0]
        g.advance(1)

        if @action
          @value = @action.call(**bindings)
        end

        @value
      end
    end
  end

  class Not < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = rule
      @value = nil
    end

    def match(g)
      unless @rule.match(g.dup)
        @value = true

        if @action
          @value = @action.call(**bindings)
        end

        @value
      end
    end
  end

  class Lookahead < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = Not.new(Not.new(rule))
      @value = nil
    end

    def match(g)
      @value = @rule.match(g)

      if @value && @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class Maybe < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = rule
      @value = nil
    end

    def match(g)
      @value = @rule.match(g)

      if @action
        @value = @action.call(**bindings)
      end

      # TODO: :not_matched is a gross hack, especially because if I want this
      # to be an Ometa implementation, we'll need to be able to pattern match
      # on symbols. A cleaner thing to do would be to rewrite this interface so
      # that the result and the state are returned. This way we can return the
      # old result if maybe fails but still succeeds.
      #
      # Another alternative would be to return a tuple [value, matched] so that
      # here we can return [nil, true] to say that we didn't get anything but
      # we still matched.
      @value || :maybe_not_matched
    end
  end

  class ZeroOrMore < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = rule
      @value = []
    end

    def match(g)
      loop do
        val = @rule.match(g)
        break unless val

        @value << val
      end

      if @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class OneOrMore < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = rule
      @value = nil
    end

    def match(g)
      val = @rule.match(g)
      return nil unless val

      @value = [val]

      until val.nil?
        val = @rule.match(g)
        @value << val if val
      end

      if @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class Grouping < Rule
    def initialize(rule, **options, &action)
      super(**options, &action)
      @rule = rule
      @value = nil
    end

    def match(g)
      @value = @rule.match(g)

      if @value && @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class Characters < Rule
    def initialize(*chars, **options, &action)
      super(**options, &action)

      if chars.size == 1 && chars[0].respond_to?(:to_a)
        chars = chars[0].to_a
      end

      @rule = OrderedChoice.new(*chars.map { |c| Literal.new(c) })
      @value = nil
    end

    def match(g)
      @value = @rule.match(g)

      if @value && @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class Call < Rule
    def initialize(grammar, target, **options, &action)
      super(**options, &action)
      @grammar = grammar
      @target = target
      @value = nil
    end

    def match(g)
      @value = @grammar[@target].match(g)

      if @value && @action
        @value = @action.call(**bindings)
      end

      @value
    end
  end

  class RuleNotFound < StandardError; end

  class Grammar
    class << self
      def target(t)
        @target = target
      end

      def match(input, target = @target)
        new(input).match(target)
      end

      alias =~ match
      alias === match

      private

      def define_proxy(*names, **explicit_mappings)
        default_mappings = names.map do |name|
          [name, Peg.const_get(name.to_s.split("_").map(&:capitalize).join)]
        end.to_h

        all_mappings = default_mappings.merge(explicit_mappings)

        all_mappings.each do |name, klass|
          define_method :"_#{name}" do |*args, &action|
            klass.new(*args, &action)
          end
        end
      end
    end

    define_proxy :any, :not, :maybe, :zero_or_more, :one_or_more,
      look: Lookahead,
      lit: Literal,
      seq: Sequence,
      or: OrderedChoice,
      group: Grouping,
      chars: Characters

    def initialize(input)
      @input = input
      @pos = 0
    end

    def match(target = @target)
      apply(target)
    end

    def apply(rule_name)
      send(rule_name).match(input)
    end

    def input
      @input[@pos..-1]
    end

    def advance(n)
      @pos += n
    end
  end
end

=begin

This is outdated. There will not be any rule creation DSL.

class Simple < Peg::Grammar
  rule :top, [[Any.new, :x], "b", [Any.new, :y]], -> { |x:, y:| x + y }
end

Simple.new.match("abc") # => "ac"
Simple.new.match("abcd") # => "ac"
Simple.new.match("ab") # => nil

class Addition < Peg::Grammar
  rule :expr, [[:num, :n], "+", [:expr, :e]], -> { |n:, e:| n + e },
              [:num]

  rule :num, [[one_or_more(:digit), :digits]], -> { |digits:| digits.join.to_i }

  rule :digit [chars("0".."9")]
end

class Simple < Peg::Grammar
  rule :top, [[Peg::Any.new, :x], "b", [Peg::Any.new, :y]], -> { |x:, y:| x + y }
end

Simple.match("abc") # => "ac"

class Number < Peg::Grammar
  target :number

  def number
    OneOrMore.new(apply(:digit), name: :digits) do |digits:|
      digits.join.to_i
    end
  end

  def digit
    Character.new(*"0".."9")
  end
end
=end

