require 'peg'

class String
  def to_netstring
    "#{bytesize}:#{self}"
  end
end

class Netstring < Peg::Grammar
  target :netstring

  def netstring
    _seq(_call(:length, name: :l), _lit(":"), _call(:repeat, :_any, _var(:l), name: :s)) { |l:, s:| s }
  end

  def length
    _one_or_more(_call(:digit), name: :ds) { |ds:| ds.join.to_i }
  end

  def digit
    _chars("0".."9")
  end

  def repeat(rule, n)
    case n
    when 1
      _call(:apply, rule)
    else
      _seq(_call(:apply, rule, name: :r), _call(:apply, :repeat, rule, n - 1, name: :rest)) do |r:, rest:|
        r + rest
      end
    end
  end
end

if $0 == __FILE__
  input = "hello".to_netstring
  puts "#{input.inspect} => #{Netstring.match(input).inspect}"
end
