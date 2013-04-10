#
# Given a string, tell us whether or not is acceptable.
#
class TextSentinel

  attr_accessor :text

  def initialize(text, opts=nil)
    @opts = opts || {}
    @text = text.encode('UTF-8', invalid: :replace, undef: :replace, replace: '') if text.present?
  end

  def self.non_symbols_regexp
    /[\ -\/\[-\`\:-\@\{-\~]/m
  end

  def self.body_sentinel(text)
    TextSentinel.new(text, min_entropy: SiteSetting.body_min_entropy)
  end

  def self.title_sentinel(text)
    TextSentinel.new(text,
                     min_entropy: SiteSetting.title_min_entropy,
                     max_word_length: SiteSetting.max_word_length)
  end

  # Entropy is a number of how many unique characters the string needs.
  def entropy
    return 0 if @text.blank?
    @entropy ||= @text.strip.each_char.to_a.uniq.size
  end

  def valid?
    # Blank strings are not valid
    return false if @text.blank? || @text.strip.blank?

    # Entropy check if required
    return false if @opts[:min_entropy].present? && (entropy < @opts[:min_entropy])

    # We don't have a comprehensive list of symbols, but this will eliminate some noise
    non_symbols = @text.gsub(TextSentinel.non_symbols_regexp, '').size
    return false if non_symbols == 0

    # Don't allow super long strings without spaces
    return false if @opts[:max_word_length] && @text =~ /\w{#{@opts[:max_word_length]},}(\s|$)/

    # We don't allow all upper case content in english
    return false if (@text =~ /[A-Z]+/) && (@text == @text.upcase)

    # It is valid
    true
  end

end
