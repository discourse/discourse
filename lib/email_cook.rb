# frozen_string_literal: true

# A very simple formatter for imported emails
class EmailCook
  def self.raw_regexp
    @raw_regexp ||=
      %r{\A\[plaintext\]$\n(.*)\n^\[/plaintext\]$(?:\s^\[attachments\]$\n(.*)\n^\[/attachments\]$)?(?:\s^\[elided\]$\n(.*)\n^\[/elided\]$)?}m
  end

  def initialize(raw)
    @raw = raw
    @body, @attachment_html, @elided = @raw.scan(EmailCook.raw_regexp).first
  end

  def add_quote(result, buffer)
    if buffer.present?
      return if buffer =~ /\A(<br>)+\z\z/
      result << "<blockquote>#{buffer}</blockquote>"
    end
  end

  def link_string!(line, unescaped_line)
    unescaped_line = unescaped_line.strip
    line.gsub!(/\S+/) do |str|
      if str.match?(%r{\A(https?://)[\S]+\z}i)
        begin
          url = URI.parse(str).to_s
          if unescaped_line == url
            # this could be oneboxed
            str = %|<a href="#{url}" class="onebox" target="_blank">#{url}</a>|
          else
            str = %|<a href="#{url}">#{url}</a>|
          end
        rescue URI::Error
          # don't fail if uri does not parse
        end
      end
      str
    end
  end

  def htmlify(text)
    result = +""
    quote_buffer = +""

    in_text = false
    in_quote = false

    text.each_line do |line|
      # replace indentation with non-breaking spaces
      line.sub!(/\A\s{2,}/) { |s| "\u00A0" * s.length }

      if line =~ /\A\s*>/
        in_quote = true
        line.sub!(/\A[\s>]*/, "")

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
          result << "<br>" if in_text && line == "\n"
          result << line
          result << "<br>"

          in_text = false
        else
          result << line
          in_text = true
        end
      end
    end

    add_quote(result, quote_buffer) if in_quote && quote_buffer.present?

    result.gsub!(/(<br>\n*){3,10}/, "<br><br>")
    result
  end

  def cook(opts = {})
    # fallback to PrettyText if we failed to detect a body
    return PrettyText.cook(@raw, opts) if @body.nil?

    result = htmlify(@body)
    result << "\n<br>" << @attachment_html if @attachment_html.present?
    result << "\n<br><br>" << Email::Receiver.elided_html(htmlify(@elided)) if @elided.present?
    result
  end
end
