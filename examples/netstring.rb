require 'ometa'

class String
  def to_netstring
    "#{bytesize}:#{self}"
  end
end

# ometa Netstring
#   target :netstring
#
#   netstring = length:l ":" repeat(:char, l):s -> s.join,
#
#   length = digit+:ds -> ds.join.to_i,
#
#   repeat rule, 1 = apply(rule):r -> [r],
#   repeat rule, n = apply(rule):r repeat(rule, n-1):rest -> ([r] + rest)
# end

class Netstring < OMeta::Parser
  target :netstring

  def netstring
    ->(input) do
      original_input = input

      l, input = _apply(input, :length)

      if _fail?(l)
        return [_fail, original_input]
      end

      _res, input = _apply(input, :token, ":")

      if _fail?(_res)
        return [_fail, original_input]
      end

      s, input = _apply(input, :repeat, :char, l)

      if _fail?(s)
        return [_fail, original_input]
      end

      [s.join, input]
    end
  end

  def length
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

  def repeat(rule, n)
    ->(input) do
      original_input = input

      case n
      when 1
        r, input = _apply(input, :apply, rule)

        return [_fail, original_input] if _fail?(r)

        [[r], input]
      else
        r, input = _apply(input, :apply, rule)

        return [_fail, original_input] if _fail?(r)

        rest, input = _apply(input, :repeat, rule, n - 1)

        return [_fail, original_input] if _fail?(rest)

        [([r] + rest), input]
      end
    end
  end
end

if $0 == __FILE__
  input = "hello".to_netstring
  puts "#{input.inspect} => #{Netstring.match(input).inspect}"
end
