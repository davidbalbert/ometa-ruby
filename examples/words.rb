class Words < Peg::Grammar
  target :words

  def words
    _or(
      _seq(_call(:words, name: :ws), _lit(" "), _call(:word, name: :w)) { |ws:, w:| puts "words <- words word"; ws + [w] },
      _call(:word, name: :w) { |w:| puts "words <- word"; [w] }
    )
  end

  def word
    _seq(_one_or_more(_chars("a".."z", "A".."Z"), name: :chars)) { |chars:| puts "word <- [a-zA-Z]"; chars.join }
  end
end
