require 'minitest/autorun'

require 'ometa'

module OMeta
  class OMetaTest < Minitest::Test
    using InputStream::Conversions

    def assert_ometa_match(parser, input, with_remaining_input:)
      p = parser.new
      assert p.match(input), "Parser didn't match #{input.inspect}"

      expected_remaining_input = with_remaining_input.to_input_stream

      assert p.input_after_match == expected_remaining_input, "Expected remaining input to be #{expected_remaining_input.inspect} but #{p.input_after_match.inspect} remains."
    end

    def test_anything
      anything = Class.new(OMeta::Parser) do
        target :whatever

        def whatever
          ->(input) { _apply(input, :anything) }
        end
      end

      assert_ometa_match anything, "a", with_remaining_input: ""
      assert_ometa_match anything, "ab", with_remaining_input: "b"
      refute_match anything, ""
    end

    def test_exactly
      exactly = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) { _apply(input, :exactly, "a") }
        end
      end

      assert_ometa_match exactly, "a", with_remaining_input: ""
      assert_ometa_match exactly, "ab", with_remaining_input: "b"
      refute_match exactly, "b"
      refute_match exactly, ""
    end

    def test_end
      the_end = Class.new(OMeta::Parser) do
        target :end
      end

      assert_ometa_match the_end, "", with_remaining_input: ""
      refute_match the_end, "a"
    end

    def test_empty
      empty = Class.new(OMeta::Parser) do
        target :empty
      end

      assert_ometa_match empty, "", with_remaining_input: ""
      assert_ometa_match empty, "a", with_remaining_input: "a"
    end

    def test_anything_or_empty
      anything_or_empty = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            _or(
              input,
              ->(input) { _apply(input, :anything) },
              ->(input) { _apply(input, :empty) }
            )
          end
        end
      end

      assert_ometa_match anything_or_empty, "", with_remaining_input: ""
      assert_ometa_match anything_or_empty, "a", with_remaining_input: ""
    end

    def test_lookahead
      lookahead = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            _lookahead(input, ->(input) { _apply(input, :exactly, "a") })
          end
        end
      end

      assert_ometa_match lookahead, "a", with_remaining_input: "a"
      refute_match lookahead, "b"
    end

    def test_zero_or_more
      zom = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            _zero_or_more(
              input,
              ->(input) { _apply(input, :exactly, "a") }
            )
          end
        end
      end

      assert_ometa_match zom, "", with_remaining_input: ""
      assert_ometa_match zom, "a", with_remaining_input: ""
      assert_ometa_match zom, "aa", with_remaining_input: ""
      assert_ometa_match zom, "aab", with_remaining_input: "b"
    end

    def test_one_or_more
      oom = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            _one_or_more(
              input,
              ->(input) { _apply(input, :exactly, "a") }
            )
          end
        end
      end

      refute_match oom, ""
      assert_ometa_match oom, "a", with_remaining_input: ""
      assert_ometa_match oom, "aa", with_remaining_input: ""
      assert_ometa_match oom, "aab", with_remaining_input: "b"
    end

    def test_space
      space = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) { _apply(input, :space) }
        end
      end

      assert_ometa_match space, " ", with_remaining_input: ""
      assert_ometa_match space, "\r\n", with_remaining_input: "\n"
    end

    def test_spaces
      spaces = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) { _apply(input, :spaces) }
        end
      end

      assert_ometa_match spaces, "", with_remaining_input: ""
      assert_ometa_match spaces, " ", with_remaining_input: ""
    end

    def test_token
      token = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) { _apply(input, :token, "hello") }
        end
      end

      assert_ometa_match token, "hello", with_remaining_input: ""
      assert_ometa_match token, "hellothere", with_remaining_input: "there"
      assert_ometa_match token, "   hellothere", with_remaining_input: "there"
      refute_match token, "hell"
      refute_match token, ""
    end

    def test_one_after_another
      one_after_another = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            res, input = _apply(input, :exactly, "a")

            if _fail?(res)
              return [res, input]
            end

            _apply(input, :exactly, "b")
          end
        end
      end

      assert_ometa_match one_after_another, "ab", with_remaining_input: ""
      assert_ometa_match one_after_another, "abc", with_remaining_input: "c"
      refute_match one_after_another, "ac"
      refute_match one_after_another, "a"
    end

    def test_apply
      apply = Class.new(OMeta::Parser) do
        target :a

        def a
          ->(input) { _apply(input, :b) }
        end

        def b
          ->(input) { _apply(input, :token, "hello") }
        end
      end

      assert_ometa_match apply, "hello", with_remaining_input: ""
      refute_match apply, "goodbye"
    end

    def test_or
      either_or = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) do
            _or(
              input,
              ->(input) { _apply(input, :exactly, "a") },
              ->(input) { _apply(input, :exactly, "b") }
            )
          end
        end
      end

      assert_ometa_match either_or, "a", with_remaining_input: ""
      assert_ometa_match either_or, "b", with_remaining_input: ""
      refute_match either_or, "c"
    end

    def test_right_recursion
      right = Class.new(OMeta::Parser) do
        target :xs

        def xs
          ->(input) do
            _or(
              input,
              ->(input) do
                res, input = _apply(input, :exactly, "x")

                if _fail?(res)
                  return [res, input]
                end

                _apply(input, :xs)
              end,
              ->(input) do
                _apply(input, :empty)
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
      left = Class.new(OMeta::Parser) do
        target :xs

        def xs
          ->(input) do
            _or(
              input,
              ->(input) do
                res, input = _apply(input, :xs)

                if _fail?(res)
                  return [res, input]
                end

                _apply(input, :exactly, "x")
              end,
              ->(input) do
                _apply(input, :empty)
              end
            )
          end
        end
      end

      assert_ometa_match left, "", with_remaining_input: ""
      assert_ometa_match left, "x", with_remaining_input: ""
      assert_ometa_match left, "xx", with_remaining_input: ""
      assert_ometa_match left, "xxy", with_remaining_input: "y"
    end

    def test_empty_list
      list = Class.new(OMeta::Parser) do
        target :top

        def top
          ->(input) do
            _nest(input, ->(input) { [nil, input] })
          end
        end
      end

      assert_ometa_match list, [[]], with_remaining_input: []
      refute_match list, [1]
    end

    def test_list
      list = Class.new(OMeta::Parser) do
        target :top

        def top
          -> (input) do
            _nest(
              input,
              ->(input) do
                res, input = _apply(input, :exactly, 1)

                if _fail?(res)
                  return [res, input]
                end

                res, input = _apply(input, :exactly, 2)

                if _fail?(res)
                  return [res, input]
                end

                _apply(input, :exactly, 3)
              end
            )
          end
        end
      end

      assert_ometa_match list, [[1,2,3]], with_remaining_input: []
      assert_ometa_match list, [[1,2,3],4], with_remaining_input: [4]
      refute_match list, [[1,2,3,4],5]
    end

    def test_foreign
      inner = Class.new(OMeta::Parser) do
        target :r

        def r
          ->(input) { _apply(input, :exactly, "a") }
        end
      end

      outer = Class.new(OMeta::Parser) do
        target :r

        define_method :r do
          ->(input) { _apply(input, :foreign, inner) }
        end
      end

      assert_ometa_match outer, "a", with_remaining_input: ""
      assert_ometa_match outer, "ab", with_remaining_input: "b"
      refute_match outer, "b"
    end
  end
end
