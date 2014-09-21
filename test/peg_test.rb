require 'minitest/autorun'

require 'peg'

module Peg
  class PegTest < Minitest::Test
    def assert_peg_match(peg, input)
      assert_match peg, Grammar.new(input)
    end

    def refute_peg_match(peg, input)
      refute_match peg, Grammar.new(input)
    end

    def test_literal
      assert_peg_match Literal.new("hello"), "hello"
      assert_peg_match Literal.new("hello"), "hello world"
      refute_peg_match Literal.new("hello"), "goodbye"
      refute_peg_match Literal.new("hello world"), "hello"
    end

    def test_sequence_peg
      peg = Sequence.new(Literal.new("a"), Literal.new("b"))
      assert_peg_match peg, "ab"
      refute_peg_match peg, "ac"
    end

    def test_ordered_choice
      peg = OrderedChoice.new(Literal.new("a"), Literal.new("b"), Literal.new("ab"))
      assert_peg_match peg, "a"
      assert_peg_match peg, "b"
      assert_peg_match peg, "ab"
      assert_peg_match peg, "abc"
      refute_peg_match peg, "cde"
    end

    def test_any
      assert_peg_match Any.new, "a"
      refute_peg_match Any.new, ""
    end

    def test_not
      assert_peg_match Not.new(Any.new), ""
      assert_peg_match Not.new(Not.new(Any.new)), "a"
    end

    def test_lookahead
      peg = Lookahead.new(Literal.new("ab"))
      assert_peg_match peg, "abc"
      refute_peg_match peg, "bbc"
    end

    def test_maybe
      peg = Maybe.new(Literal.new("a"))
      assert_peg_match peg, "a"
      assert_peg_match peg, "b"
    end

    def test_zero_or_more
      peg = ZeroOrMore.new(Literal.new("a"))
      assert_peg_match peg, ""
      assert_peg_match peg, "a"
      assert_peg_match peg, "aa"
    end

    def test_one_or_more
      peg = OneOrMore.new(Literal.new("a"))
      refute_peg_match peg, ""
      assert_peg_match peg, "a"
      assert_peg_match peg, "aa"
    end

    def test_grouping
      assert_peg_match Grouping.new(Literal.new("abc")), "abc"
    end

    def test_chars
      peg = Characters.new(?a, ?b, ?c)
      assert_peg_match peg, "a"
      assert_peg_match peg, "b"
      assert_peg_match peg, "c"
      refute_peg_match peg, "d"
    end

    def test_grammar
      g = Class.new(Grammar) do
        target :top

        def top
          _seq(_lit("hello"), _lit("world"))
        end
      end

      assert_match g, "helloworld"
      assert_match g, "helloworldfoo"
      refute_match g, "hello"
    end

    def test_captured_rule
      g = Class.new(Grammar) do
        target :top

        def top
          _seq(_any(name: :x), _lit("b"), _any(name: :y)) { |x:, y:| (x + y).upcase }
        end
      end

      assert_equal "AC", g.match("abc")
    end

    def test_apply
      g = Class.new(Grammar) do
        target :top

        def top
          _call(:apply, :hello)
        end

        def hello
          _lit("hello")
        end
      end

      assert_match g, "hello"
    end
  end
end
