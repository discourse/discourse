#
# Handles an incoming message
#

module Email
  class Receiver

    def self.results
      @results ||= Enum.new(:unprocessable, :missing, :processed)
    end

    attr_reader :body, :reply_key, :email_log

    def initialize(raw)
      @raw = raw
    end

    def process
      return Email::Receiver.results[:unprocessable] if @raw.blank?

      @message = Mail::Message.new(@raw)
      @body = EmailReplyParser.read(parse_body).visible_text

      return Email::Receiver.results[:unprocessable] if @body.blank?

      @reply_key = @message.to.first

      # Extract the `reply_key` from the format the site has specified
      tokens = SiteSetting.reply_by_email_address.split("%{reply_key}")
      tokens.each do |t|
        @reply_key.gsub!(t, "") if t.present?
      end

      # Look up the email log for the reply key
      @email_log = EmailLog.for(reply_key)
      return Email::Receiver.results[:missing] if @email_log.blank?

      create_reply

      Email::Receiver.results[:processed]
    end

    private

    def parse_body
      html = nil

      # If the message is multipart, find the best type for our purposes
      if @message.multipart?
        @message.parts.each do |p|
          if p.content_type =~ /text\/plain/
            return p.body.to_s
          elsif p.content_type =~ /text\/html/
            html = p.body.to_s
          end
        end
      end

      html = @message.body.to_s if @message.content_type =~ /text\/html/
      if html.present?
        return scrub_html(html)
      end

      return @message.body.to_s.strip
    end

    def scrub_html(html)
      # If we have an HTML message, strip the markup
      doc = Nokogiri::HTML(html)

      # Blackberry is annoying in that it only provides HTML. We can easily
      # extract it though
      content = doc.at("#BB10_response_div")
      return content.text if content.present?

      return doc.xpath("//text()").text
    end

    def create_reply

      # Try to post the body as a reply
      creator = PostCreator.new(email_log.user,
                                raw: @body,
                                topic_id: @email_log.topic_id,
                                reply_to_post_number: @email_log.post.post_number,
                                cooking_options: {traditional_markdown_linebreaks: true})

      creator.create
    end

  end
end
