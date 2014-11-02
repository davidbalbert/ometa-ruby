require 'minitest/autorun'

require 'peg'

module Peg
  class PegTest < Minitest::Test
    def test_anything
      anything = Class.new(Peg::Parser) do
        target :whatever

        def whatever
          -> { _apply(:anything) }
        end
      end

      assert_match anything, "a"
      assert_match anything, "ab"
      refute_match anything, ""
    end

    def test_exactly
      exactly = Class.new(Peg::Parser) do
        target :r

        def r
          -> { _apply(:exactly, "a") }
        end
      end

      assert_match exactly, "a"
      assert_match exactly, "ab"
      refute_match exactly, "b"
      refute_match exactly, ""
    end

    def test_end
      the_end = Class.new(Peg::Parser) do
        target :end
      end

      assert_match the_end, ""
      refute_match the_end, "a"
    end

    def test_empty
      empty = Class.new(Peg::Parser) do
        target :empty
      end

      assert_match empty, ""
      assert_match empty, "a"
    end

    def test_anything_or_empty
      anything_or_empty = Class.new(Peg::Parser) do
        target :r

        def r
          -> do
            _or(
              -> { _apply(:anything) },
              -> { _apply(:empty) }
            )
          end
        end
      end

      assert_match anything_or_empty, ""
      assert_match anything_or_empty, "a"
    end

    def test_lookahead
      lookahead = Class.new(Peg::Parser) do
        target :r

        def r
          -> do
            _lookahead(-> { _apply(:exactly, "a") })
            _apply(:anything)
          end
        end
      end

      assert_match lookahead, "a"
      refute_match lookahead, "b"
    end

    def test_literal
      literal = Class.new(Peg::Parser) do
        target :r

        def r
          -> { _apply(:literal, "hello") }
        end
      end

      assert_match literal, "hello"
      assert_match literal, "hellothere"
      refute_match literal, "hell"
      refute_match literal, ""
    end

    def test_one_after_another
      one_after_another = Class.new(Peg::Parser) do
        target :r

        def r
          -> do
            _apply(:exactly, "a")
            _apply(:exactly, "b")
          end
        end
      end

      assert_match one_after_another, "ab"
      assert_match one_after_another, "abc"
      refute_match one_after_another, "ac"
      refute_match one_after_another, "a"
    end

    def test_apply
      apply = Class.new(Peg::Parser) do
        target :a

        def a
          -> { _apply(:b) }
        end

        def b
          -> { _apply(:literal, "hello") }
        end
      end

      assert_match apply, "hello"
      refute_match apply, "goodbye"
    end

    def test_or
      either_or = Class.new(Peg::Parser) do
        target :r

        def r
          -> do
            _or(-> { _apply(:exactly, "a") },
                -> { _apply(:exactly, "b") })
          end
        end
      end

      assert_match either_or, "a"
      assert_match either_or, "b"
      refute_match either_or, "c"
    end

    def test_right_recursion
      right = Class.new(Peg::Parser) do
        target :xs

        def xs
          -> do
            _or(
              -> do
                _apply(:exactly, "x")
                _apply(:xs)
              end,
              -> do
                _apply(:empty)
              end
            )
          end
        end
      end

      assert_match right, ""
      assert_match right, "x"
      assert_match right, "xx"
      assert_match right, "xxy"
    end
  end

  def test_left_recursion
    left = Class.new(Peg::Parser) do
      target :xs

      def xs
        -> do
          _or(
            -> do
              _apply(:xs)
              apply(:exactly, "x")
            end,
            -> do
              _apply(:empty)
            end
          )
        end
      end
    end

    assert_match left, ""
    assert_match left, "x"
    assert_match left, "xx"
    assert_match left, "xxy"
  end
end
