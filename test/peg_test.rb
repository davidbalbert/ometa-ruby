require 'minitest/autorun'

require 'peg'

module Peg
  class PegTest < Minitest::Test
    def assert_ometa_match(parser, input, with_remaining_input:)
      p = parser.new(input)
      assert p.match, "Parser didn't match #{input.inspect}"

      remaining_input = p.instance_variable_get(:@input)

      assert remaining_input == with_remaining_input, "Expected remaining input to be #{with_remaining_input.inspect} but #{remaining_input.inspect} remains."
    end

    def test_anything
      anything = Class.new(Peg::Parser) do
        target :whatever

        def whatever
          -> { _apply(:anything) }
        end
      end

      assert_ometa_match anything, "a", with_remaining_input: ""
      assert_ometa_match anything, "ab", with_remaining_input: "b"
      refute_match anything, ""
    end

    def test_exactly
      exactly = Class.new(Peg::Parser) do
        target :r

        def r
          -> { _apply(:exactly, "a") }
        end
      end

      assert_ometa_match exactly, "a", with_remaining_input: ""
      assert_ometa_match exactly, "ab", with_remaining_input: "b"
      refute_match exactly, "b"
      refute_match exactly, ""
    end

    def test_end
      the_end = Class.new(Peg::Parser) do
        target :end
      end

      assert_ometa_match the_end, "", with_remaining_input: ""
      refute_match the_end, "a"
    end

    def test_empty
      empty = Class.new(Peg::Parser) do
        target :empty
      end

      assert_ometa_match empty, "", with_remaining_input: ""
      assert_ometa_match empty, "a", with_remaining_input: "a"
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

      assert_ometa_match anything_or_empty, "", with_remaining_input: ""
      assert_ometa_match anything_or_empty, "a", with_remaining_input: ""
    end

    def test_lookahead
      lookahead = Class.new(Peg::Parser) do
        target :r

        def r
          -> do
            _lookahead(-> { _apply(:exactly, "a") })
          end
        end
      end

      assert_ometa_match lookahead, "a", with_remaining_input: "a"
      refute_match lookahead, "b"
    end

    def test_literal
      literal = Class.new(Peg::Parser) do
        target :r

        def r
          -> { _apply(:literal, "hello") }
        end
      end

      assert_ometa_match literal, "hello", with_remaining_input: ""
      assert_ometa_match literal, "hellothere", with_remaining_input: "there"
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

      assert_ometa_match one_after_another, "ab", with_remaining_input: ""
      assert_ometa_match one_after_another, "abc", with_remaining_input: "c"
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

      assert_ometa_match apply, "hello", with_remaining_input: ""
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

      assert_ometa_match either_or, "a", with_remaining_input: ""
      assert_ometa_match either_or, "b", with_remaining_input: ""
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

      assert_ometa_match right, "", with_remaining_input: ""
      assert_ometa_match right, "x", with_remaining_input: ""
      assert_ometa_match right, "xx", with_remaining_input: ""
      assert_ometa_match right, "xxy", with_remaining_input: "y"
    end

    def test_left_recursion
      left = Class.new(Peg::Parser) do
        target :xs

        def xs
          -> do
            _or(
              -> do
                _apply(:xs)
                _apply(:exactly, "x")
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
end
