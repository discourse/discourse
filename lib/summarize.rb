# Summarize a HTML field into regular text. Used currently
# for meta tags

require 'sanitize'

class Summarize

  def initialize(text)
    @text = text
  end

  def self.max_length
    500
  end

  def summary
    return nil if @text.blank?

    result = Sanitize.clean(@text)
    result.gsub!(/\n/, ' ')
    result.strip!

    return result if result.length <= Summarize.max_length
    "#{result[0..Summarize.max_length]}..."
  end

end
