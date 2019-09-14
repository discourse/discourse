# frozen_string_literal: true

# A very simple formatter for imported emails
class EmailCook

  def self.url_regexp
    @url_regexp ||= /((?:https?:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/
  end

  def self.raw_regexp
    @raw_regexp ||= /^\[plaintext\]$\n(.*)\n^\[\/plaintext\]$(?:\s^\[attachments\]$\n(.*)\n^\[\/attachments\]$)?(?:\s^\[elided\]$\n(.*)\n^\[\/elided\]$)?/m
  end

  def initialize(raw)
    @raw = raw
    @body, @attachment_html, @elided = @raw.scan(EmailCook.raw_regexp).first
  end

  def add_quote(result, buffer)
    if buffer.present?
      return if buffer =~ /\A(<br>)+\z$/
      result << "<blockquote>#{buffer}</blockquote>"
    end
  end

  def link_string!(line, unescaped_line)
    unescaped_line = unescaped_line.strip
    unescaped_line.scan(EmailCook.url_regexp).each do |m|
      url = m[0]

      if unescaped_line == url
        # this could be oneboxed
        val = %|<a href="#{url}" class="onebox" target="_blank">#{url}</a>|
      else
        val = %|<a href="#{url}">#{url}</a>|
      end

      line.gsub!(url, val)
    end
  end

  def htmlify(text)
    result = +""
    quote_buffer = +""

    in_text = false
    in_quote = false

    text.each_line do |line|
      # replace indentation with non-breaking spaces
      line.sub!(/^\s{2,}/) { |s| "\u00A0" * s.length }

      if line =~ /^\s*>/
        in_quote = true
        line.sub!(/^[\s>]*/, '')

        unescaped_line = line
        line = CGI.escapeHTML(line)
        link_string!(line, unescaped_line)

        quote_buffer << line << "<br>"
      elsif in_quote
        add_quote(result, quote_buffer)
        quote_buffer = ""
        in_quote = false
      else

        sz = line.size

        unescaped_line = line
        line = CGI.escapeHTML(line)
        link_string!(line, unescaped_line)

        if sz < 60
          if in_text && line == "\n"
            result << "<br>"
          end
          result << line
          result << "<br>"

          in_text = false
        else
          result << line
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

  def cook(opts = {})
    # fallback to PrettyText if we failed to detect a body
    return PrettyText.cook(@raw, opts) if @body.nil?

    result =  htmlify(@body)
    result << "\n<br>" << @attachment_html if @attachment_html.present?
    result << "\n<br><br>" << Email::Receiver.elided_html(htmlify(@elided)) if @elided.present?
    result
  end

end
