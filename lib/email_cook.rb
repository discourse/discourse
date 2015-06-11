# A very simple formatter for imported emails
class EmailCook

  def initialize(raw)
    @raw = raw
  end

  def cook
    result = ""

    in_quote = false
    quote_buffer = ""
    @raw.each_line do |l|

      if l =~ /^\s*>/
        in_quote = true
        quote_buffer << l.sub(/^[\s>]*/, '') << "<br>"
      elsif in_quote
        result << "<blockquote>#{quote_buffer}</blockquote>"
        quote_buffer = ""
        in_quote = false
      else
        result << l << "<br>"
      end
    end

    if in_quote
      result << "<blockquote>#{quote_buffer}</blockquote>"
    end

    result.gsub!(/(<br>){3,10}/, '<br><br>')

    result
  end

end
