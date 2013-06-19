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
      parse_body

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
      @body = @message.body.to_s.strip
      return if @body.blank?

      # I really hate to have to do this, but there seems to be a bug in Mail::Message
      # with content boundaries in emails. Until it is fixed, this hack removes stuff
      # we don't want from emails bodies
      content_type = @message.header['Content-Type'].to_s
      if content_type.present?
        boundary_match = content_type.match(/boundary\=(.*)$/)
        boundary = boundary_match[1] if boundary_match && boundary_match[1].present?
        if boundary.present? and @body.present?

          lines = @body.lines
          lines = lines[1..-1] if lines.present? and lines[0] =~ /^--#{boundary}/
          lines = lines[1..-1] if lines.present? and lines[0] =~ /^Content-Type/

          @body = lines.join.strip!
        end
      end

      @body = EmailReplyParser.read(@body).visible_text
    end

    def create_reply

      # Try to post the body as a reply
      creator = PostCreator.new(email_log.user,
                                raw: @body,
                                topic_id: @email_log.topic_id,
                                reply_to_post_number: @email_log.post.post_number)

      creator.create
    end

  end
end
