require 'minitest/autorun'

require 'peg'

module Peg
  class PegTest < Minitest::Test
    def test_string_rule
      assert_match Literal.new("hello"), "hello"
      assert_match Literal.new("hello"), "hello world"
      refute_match Literal.new("hello"), "goodbye"
      refute_match Literal.new("hello world"), "hello"
    end

    def test_sequence_peg
      peg = Sequence.new(Literal.new("a"), Literal.new("b"))
      assert_match peg, "ab"
      refute_match peg, "ac"
    end

    def test_ordered_choice
      peg = OrderedChoice.new(Literal.new("a"), Literal.new("b"), Literal.new("ab"))
      assert_match peg, "a"
      assert_match peg, "b"
      assert_match peg, "ab"
      assert_match peg, "abc"
      refute_match peg, "cde"
    end

    def test_any
      assert_match Any.new, "a"
      refute_match Any.new, ""
    end

    def test_not
      assert_match Not.new(Any.new), ""
      assert_match Not.new(Not.new(Any.new)), "a"
    end

    def test_lookahead
      peg = Lookahead.new(Literal.new("ab"))
      assert_match peg, "abc"
      refute_match peg, "bbc"
    end

    def test_maybe
      peg = Maybe.new(Literal.new("a"))
      assert_match peg, "a"
      assert_match peg, "b"
    end

    def test_zero_or_more
      peg = ZeroOrMore.new(Literal.new("a"))
      assert_match peg, ""
      assert_match peg, "a"
      assert_match peg, "aa"
    end

    def test_one_or_more
      peg = OneOrMore.new(Literal.new("a"))
      refute_match peg, ""
      assert_match peg, "a"
      assert_match peg, "aa"
    end

    def test_grouping
      assert_match Grouping.new(Literal.new("abc")), "abc"
    end

    def test_chars
      peg = Characters.new(?a, ?b, ?c)
      assert_match peg, "a"
      assert_match peg, "b"
      assert_match peg, "c"
      refute_match peg, "d"
    end

    def test_grammar
      g = Class.new(Grammar) do
        rule :top, [["hello", :x], "world"]
      end

      assert_match g, "helloworld"
      assert_match g, "helloworldfoo"
      refute_match g, "hello"
    end

    def test_captured_rule
      g = Class.new(Grammar) do
        rule :top, [[any, :x], "b", [any, :y]] { |x:, y:| x + y }
      end

      assert_equal "ac", g.match("abc")
    end
  end
end
