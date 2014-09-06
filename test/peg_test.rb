require 'minitest/autorun'

require 'peg'

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
