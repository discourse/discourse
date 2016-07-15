# A very simple formatter for imported emails

class EmailCook

  def self.url_regexp
    /^((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/
  end

  def initialize(raw)
    @raw = raw
  end

  def add_quote(result, buffer)
    if buffer.present?
      return if buffer =~ /\A(<br>)+\z$/
      result << "<blockquote>#{buffer}</blockquote>"
    end
  end

  def cook
    result = ""

    in_text = false
    in_quote = false

    quote_buffer = ""
    @raw.each_line do |l|

      if l =~ /^\s*>/
        in_quote = true
        quote_buffer << l.sub(/^[\s>]*/, '') << "<br>"
      elsif in_quote
        add_quote(result, quote_buffer)
        quote_buffer = ""
        in_quote = false
      else

        sz = l.size

        l.scan(EmailCook.url_regexp).each do |m|
          url = m[0]
          l.gsub!(url, "<a href='#{url}'>#{url}</a>")
        end

        result << l

        if sz < 60
          result << "<br>"
          if in_text
            result << "<br>"
          end
          in_text = false
        else
          in_text = true
        end
      end
    end

    if in_quote && quote_buffer.present?
      add_quote(result, quote_buffer)
    end

    result.gsub!(/(<br>\n*){3,10}/, '<br><br>')
    result
  end

end
