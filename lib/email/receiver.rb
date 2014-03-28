#
# Handles an incoming message
#

module Email
  class Receiver

    class ProcessingError < StandardError; end
    class EmailUnparsableError < ProcessingError; end
    class EmptyEmailError < ProcessingError; end
    class UserNotFoundError < ProcessingError; end
    class UserNotSufficientTrustLevelError < ProcessingError; end
    class EmailLogNotFound < ProcessingError; end

    attr_reader :body, :reply_key, :email_log

    def initialize(raw)
      @raw = raw
    end

    def is_in_email?
      @allow_strangers = false
      if SiteSetting.email_in and SiteSetting.email_in_address == @message.to.first
        @category_id = SiteSetting.email_in_category.to_i
        return true
      end

      category = Category.find_by_email(@message.to.first)
      return false if not category

      @category_id = category.id
      @allow_strangers = category.email_in_allow_strangers
      return true

    end

    def process
      raise EmptyEmailError if @raw.blank?

      @message = Mail.new(@raw)


      # First remove the known discourse stuff.
      parse_body
      raise EmptyEmailError if @body.blank?

      # Then run the github EmailReplyParser on it in case we didn't catch it
      @body = EmailReplyParser.read(@body).visible_text.force_encoding('UTF-8')

      discourse_email_parser

      raise EmailUnparsableError if @body.blank?

      if is_in_email?
        @user = User.find_by_email(@message.from.first)
        if @user.blank? and @allow_strangers
          wrap_body_in_quote
          @user = Discourse.system_user
        end

        raise UserNotFoundError if @user.blank?
        raise UserNotSufficientTrustLevelError.new @user if not @user.has_trust_level?(TrustLevel.levels[SiteSetting.email_in_min_trust.to_i])

        create_new_topic
      else
        @reply_key = @message.to.first

        # Extract the `reply_key` from the format the site has specified
        tokens = SiteSetting.reply_by_email_address.split("%{reply_key}")
        tokens.each do |t|
          @reply_key.gsub!(t, "") if t.present?
        end

        # Look up the email log for the reply key
        @email_log = EmailLog.for(reply_key)
        raise EmailLogNotFound if @email_log.blank?

        create_reply
      end
    end

    private

    def wrap_body_in_quote
      @body = "[quote=\"#{@message.from.first}\"]
#{@body}
[/quote]"
    end

    def parse_body
      html = nil

      # If the message is multipart, find the best type for our purposes
      if @message.multipart?
        if p = @message.text_part
          @body = p.charset ? p.body.decoded.force_encoding(p.charset).encode("UTF-8").to_s : p.body.to_s
          return @body
        elsif p = @message.html_part
          html = p.charset ? p.body.decoded.force_encoding(p.charset).encode("UTF-8").to_s : p.body.to_s
        end
      end

      if @message.content_type =~ /text\/html/
        if defined? @message.charset
          html = @message.body.decoded.force_encoding(@message.charset).encode("UTF-8").to_s 
        else
          html = @message.body.to_s
        end
      end

      if html.present?
        @body = scrub_html(html)
        return @body
      end

      @body = @message.charset ? @message.body.decoded.force_encoding(@message.charset).encode("UTF-8").to_s.strip : @message.body.to_s

      # Certain trigger phrases that means we didn't parse correctly
      @body = nil if @body =~ /Content\-Type\:/ ||
                     @body =~ /multipart\/alternative/ ||
                     @body =~ /text\/plain/

      @body
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
      lines = @body.scrub.lines.to_a
      range_end = 0

      lines.each_with_index do |l, idx|
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

    def create_new_topic
      # Try to post the body as a reply
      topic_creator = TopicCreator.new(@user,
                                       Guardian.new(@user), 
                                       category: @category_id,
                                       title: @message.subject)

      topic = topic_creator.create
      post_creator = PostCreator.new(@user,
                                     raw: @body,
                                     topic_id: topic.id,
                                     cooking_options: {traditional_markdown_linebreaks: true})

      post_creator.create
      EmailLog.create(email_type: "topic_via_incoming_email",
            to_address: @message.to.first,
            topic_id: topic.id, user_id: @user.id)
      topic
    end

  end
end
