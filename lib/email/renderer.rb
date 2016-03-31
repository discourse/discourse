require_dependency 'email/styles'

module Email
  class Renderer

    def initialize(message, opts=nil)
      @message = message
      @opts = opts || {}
    end

    def text
      return @text if @text
      @text = (@message.text_part ? @message.text_part : @message).body.to_s.force_encoding('UTF-8')
      @text = CGI.unescapeHTML(@text)
    end

    def html
      if @message.html_part
        style = Email::Styles.new(@message.html_part.body.to_s, @opts)
        style.format_basic
        style.format_html
      else
        style = Email::Styles.new(PrettyText.cook(text), @opts)
        style.format_basic
      end

      style.to_html
    end

  end
end
