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


      # First remove the known discourse stuff.
      parse_body
      return Email::Receiver.results[:unprocessable] if @body.blank?

      # Then run the github EmailReplyParser on it in case we didn't catch it
      @body = EmailReplyParser.read(@body).visible_text.force_encoding('UTF-8')

      discourse_email_parser

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
            @body = p.body.to_s
            return @body
          elsif p.content_type =~ /text\/html/
            html = p.body.to_s
          end
        end
      end

      html = @message.body.to_s if @message.content_type =~ /text\/html/
      if html.present?
        @body = scrub_html(html)
        return @body
      end

      @body = @message.body.to_s.strip
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

    def discourse_email_parser
      lines = @body.lines.to_a
      range_end = 0

      email_year = lines.each_with_index do |l, idx|
        break if l =~ /\A\s*\-{3,80}\s*\z/ ||
                 l =~ Regexp.new("\\A\\s*" + I18n.t('user_notifications.previous_discussion') + "\\s*\\Z") ||
                 (l =~ /via #{SiteSetting.title}(.*)\:$/) ||
                 # This one might be controversial but so many reply lines have years, times and end with a colon.
                 # Let's try it and see how well it works.
                 (l =~ /\d{4}/ && l =~ /\d:\d\d/ && l =~ /\:$/)

        range_end = idx
      end

      @body = lines[0..range_end].join
      @body.strip!
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
