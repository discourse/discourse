#
# Handles an incoming message
#

module Email

  class Receiver

    include ActionView::Helpers::NumberHelper

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
        if @user.blank? && @allow_strangers
          wrap_body_in_quote
          @user = Discourse.system_user
        end

        raise UserNotFoundError if @user.blank?
        raise UserNotSufficientTrustLevelError.new @user unless @user.has_trust_level?(TrustLevel.levels[SiteSetting.email_in_min_trust.to_i])

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

      # Blackberry is annoying in that it only provides HTML. We can easily extract it though
      content = doc.at("#BB10_response_div")
      return content.text if content.present?

      doc.xpath("//text()").text
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

    def is_in_email?
      @allow_strangers = false

      if SiteSetting.email_in && SiteSetting.email_in_address == @message.to.first
        @category_id = SiteSetting.email_in_category.to_i
        return true
      end

      category = Category.find_by_email(@message.to.first)
      return false unless category

      @category_id = category.id
      @allow_strangers = category.email_in_allow_strangers

      true
    end

    def wrap_body_in_quote
      @body = "[quote=\"#{@message.from.first}\"]
#{@body}
[/quote]"
    end

    def create_reply
      create_post_with_attachments(email_log.user, @body, @email_log.topic_id, @email_log.post.post_number)
    end

    def create_new_topic
      topic = TopicCreator.new(
        @user,
        Guardian.new(@user),
        category: @category_id,
        title: @message.subject,
      ).create

      post = create_post_with_attachments(@user, @body, topic.id)

      EmailLog.create(
        email_type: "topic_via_incoming_email",
        to_address: @message.to.first,
        topic_id: topic.id,
        user_id: @user.id,
      )

      post
    end

    def create_post_with_attachments(user, raw, topic_id, reply_to_post_number=nil)
      options = {
        raw: raw,
        topic_id: topic_id,
        cooking_options: { traditional_markdown_linebreaks: true },
      }
      options[:reply_to_post_number] = reply_to_post_number if reply_to_post_number

      # deal with attachments
      @message.attachments.each do |attachment|
        tmp = Tempfile.new("discourse-email-attachment")
        begin
          # read attachment
          File.open(tmp.path, "w+b") { |f| f.write attachment.body.decoded }
          # create the upload for the user
          upload = Upload.create_for(user.id, tmp, attachment.filename, File.size(tmp))
          if upload && upload.errors.empty?
            # TODO: should use the same code as the client to insert attachments
            raw << "\n#{attachment_markdown(upload)}\n"
          end
        ensure
          tmp.close!
        end

      end

      create_post(user, options)
    end

    def attachment_markdown(upload)
      if FileHelper.is_image?(upload.original_filename)
        "<img src='#{upload.url}' width='#{upload.width}' height='#{upload.height}'>"
      else
        "<a class='attachment' href='#{upload.url}'>#{upload.original_filename}</a> (#{number_to_human_size(upload.filesize)})"
      end
    end

    def create_post(user, options)
      PostCreator.new(user, options).create
    end

  end
end
