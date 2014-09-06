require 'minitest/autorun'

require 'peg'

module Peg
  class PegTest < Minitest::Test
    def assert_matches(input, peg)
      assert peg.match(input), "`peg' did not match `#{input}'"
    end

    def assert_doesnt_match(input, peg)
      assert_nil peg.match(input), "`peg' matched `#{input}' when it shouldn't have"
    end

    def test_string_rule
      assert_matches "hello", Literal.new("hello")
      assert_matches "hello world", Literal.new("hello")
      assert_doesnt_match "goodbye", Literal.new("hello")
      assert_doesnt_match "hello", Literal.new("hello world")
    end

    def test_sequence_peg
      peg = Sequence.new(Literal.new("a"), Literal.new("b"))
      assert_matches "ab", peg
      assert_doesnt_match "ac", peg
    end

    def test_ordered_choice
      peg = OrderedChoice.new(Literal.new("a"), Literal.new("b"), Literal.new("ab"))
      assert_matches "a", peg
      assert_matches "b", peg
      assert_matches "ab", peg
      assert_matches "abc", peg
      assert_doesnt_match "cde", peg
    end

    def test_any
      assert_matches "a", Any.new
      assert_doesnt_match "", Any.new
    end

    def test_not
      assert_matches "", Not.new(Any.new)
      assert_matches "a", Not.new(Not.new(Any.new))
    end

    def test_lookahead
      peg = Lookahead.new(Literal.new("ab"))
      assert_matches "abc", peg
      assert_doesnt_match "bbc", peg
    end

    def test_maybe
      peg = Maybe.new(Literal.new("a"))
      assert_matches "a", peg
      assert_matches "b", peg
    end

    def test_zero_or_more
      peg = ZeroOrMore.new(Literal.new("a"))
      assert_matches "", peg
      assert_matches "a", peg
      assert_matches "aa", peg
    end

    def test_one_or_more
      peg = OneOrMore.new(Literal.new("a"))
      assert_doesnt_match "", peg
      assert_matches "a", peg
      assert_matches "aa", peg
    end

    def test_grouping
      assert_matches "abc", Grouping.new(Literal.new("abc"))
    end

    def test_chars
      peg = Characters.new(?a, ?b, ?c)
      assert_matches "a", peg
      assert_matches "b", peg
      assert_matches "c", peg
      assert_doesnt_match "d", peg
    end

    def test_grammar
      g = Class.new(Peg::Grammar) do
        rule :top, ["hello", :x], "world"
      end

      assert_matches "helloworld", g
      assert_matches "helloworldfoo", g
      assert_doesnt_match "hello", g
    end
  end
end
