require 'peg'

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

class Bencode < Peg::Grammar
  target :value

  def value
    _or(_call(:int), _call(:string), _call(:list), _call(:dict))
  end

  def int
    _seq(_lit("i"), _call(:number, name: :num), _lit("e")) { |num:| num }
  end

  def number
    _seq(_maybe(_lit("-"), name: :neg), _call(:positive_number, name: :num)) do |neg:, num:|
      if neg
        -1 * num
      else
        num
      end
    end
  end

  def positive_number
    _one_or_more(_chars("0".."9"), name: :ds) { |ds:| ds.join.to_i }
  end

  def string
    _call(:foreign, Netstring)
  end

  def list
    _seq(_lit("l"), _zero_or_more(_call(:value), name: :values), _lit("e")) { |values:| values }
  end

  def dict
    _seq(_lit("d"), _zero_or_more(_call(:pair), name: :pairs), _lit("e")) { |pairs:| pairs.to_h }
  end

  def pair
    _seq(_call(:string, name: :s), _call(:value, name: :v)) { |s:, v:| [s, v] }
  end
end

if $0 == __FILE__
  input = {foo: 4, bar: [1,2,3]}.bencode
  puts "#{input.inspect} => #{Bencode.match(input).inspect}"
end
