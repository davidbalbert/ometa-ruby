require 'ometa'

# ometa Words
#   target :words
#
#   words = words:ws word:w -> (ws + [w])
#         | word:w -> [w],
#
#   word = spaces letter+:ls -> ls.join,
#
#   letter = char:c ?(("a".."z").include?(c) || ("A".."Z").include?(c)) -> c
# end

class Words < OMeta::Parser
  target :words

  def words
    ->(input) do
      _or(
        input,
        -> (input) do
          original_input = input

          ws, input = _apply(input, :words)

          if _fail?(ws)
            return [_fail, original_input]
          end

          w, input = _apply(input, :word)

          if _fail?(w)
            return [_fail, original_input]
          end

          [(ws + [w]), input]
        end,
        -> (input) do
          original_input = input

          w, input = _apply(input, :word)

          if _fail?(w)
            return [_fail, original_input]
          end

          [[w], input]
        end
      )
    end
  end

  def word
    ->(input) do
      original_input = input

      _res, input = _apply(input, :spaces)

      if _fail?(_res)
        return [_fail, original_input]
      end

      ls, input = _one_or_more(
        input,
        ->(input) { _apply(input, :letter) }
      )

      if _fail?(ls)
        return [_fail, original_input]
      end

      [ls.join, input]
    end
  end

  def letter
    ->(input) do
      original_input = input

      c, input = _apply(input, :char)

      if _fail?(c)
        return [_fail, original_input]
      end

      unless ("a".."z").include?(c) || ("A".."Z").include?(c)
        return [_fail, original_input]
      end

      [c, input]
    end
  end
end

p Words.match "Hello OMeta"
