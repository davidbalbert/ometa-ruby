require 'ometa'

require_relative 'netstring'

class String
  def bencode
    to_netstring
  end
end

class Symbol
  def bencode
    to_s.bencode
  end
end

class Integer
  def bencode
    "i#{to_s}e"
  end
end

class Array
  def bencode
    "l#{map(&:bencode).join}e"
  end
end

class Hash
  def bencode
    "d#{sort.map {|k,v| k.bencode + v.bencode}.join}e"
  end
end

# ometa Bencode
#   target :value
#
#   value = int | string | list | dict,
#
#   int = "i" number:num "e" -> num,
#
#   number = "-"?:neg positive_number:num -> (neg ? -1 * num : num),
#
#   positive_number = digit+:ds -> ds.join.to_i
#
#   string = foreign(Netstring)
#
#   list = "l" value*:values "e" -> values
#
#   dict = "d" pair*:pairs "e" -> pairs.to_h
#
#   pair = string:s value:v -> [s, v]
# end
class Bencode < OMeta::Parser
  target :value

  def value
    ->(input) do
      original_input = input

      _or(
        input,
        ->(input) { _apply(input, :int) },
        ->(input) { _apply(input, :string) },
        ->(input) { _apply(input, :list) },
        ->(input) { _apply(input, :dict) }
      )
    end
  end

  def int
    ->(input) do
      original_input = input

      _res, input = _apply(input, :token, "i")

      if _fail?(_res)
        return [_fail, original_input]
      end

      num, input = _apply(input, :number)

      if _fail?(num)
        return [_fail, original_input]
      end

      _res, input = _apply(input, :token, "e")

      if _fail?(_res)
        return [_fail, original_input]
      end

      [num, input]
    end
  end

  def number
    ->(input) do
      original_input = input

      neg, input = _maybe(
        input,
        ->(input) { _apply(input, :token, "-") }
      )

      if _fail?(neg)
        return [FAIL, original_input]
      end

      num, input = _apply(input, :positive_number)

      if _fail?(num)
        return [FAIL, original_input]
      end

      [(neg ? -1 * num : num), input]
    end
  end

  def positive_number
    ->(input) do
      original_input = input

      ds, input = _one_or_more(
        input,
        ->(input) { _apply(input, :digit) }
      )

      if _fail?(ds)
        return [_fail, original_input]
      end

      [ds.join.to_i, input]
    end
  end

  def string
    ->(input) do
      original_input = input

      _apply(input, :foreign, Netstring)
    end
  end

  def list
    ->(input) do
      original_input = input

      _res, input = _apply(input, :token, "l")

      if _fail?(_res)
        return [_fail, original_input]
      end

      values, input = _zero_or_more(
        input,
        ->(input) { _apply(input, :value) }
      )

      if _fail?(values)
        return [_fail, original_input]
      end

      _res, input = _apply(input, :token, "e")

      if _fail?(_res)
        return [_fail, original_input]
      end

      [values, input]
    end
  end

  def dict
    ->(input) do
      original_input = input

      _res, input = _apply(input, :token, "d")

      if _fail?(_res)
        return [_fail, original_input]
      end

      pairs, input = _zero_or_more(
        input,
        ->(input) { _apply(input, :pair) }
      )

      if _fail?(pairs)
        return [_fail, original_input]
      end

      _res, input = _apply(input, :token, "e")

      if _fail?(_res)
        return [_fail, original_input]
      end

      [pairs.to_h, input]
    end
  end

  def pair
    ->(input) do
      original_input = input

      s, input = _apply(input, :string)

      if _fail?(s)
        return [_fail, original_input]
      end

      v, input = _apply(input, :value)

      if _fail?(v)
        return [_fail, original_input]
      end

      [[s, v], input]
    end
  end
end

if $0 == __FILE__
  input = {foo: 4, bar: [1,2,3]}.bencode
  puts "#{input.inspect} => #{Bencode.match(input).inspect}"
end
