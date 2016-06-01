#
# A helper class to send an email. It will also handle a nil message, which it considers
# to be "do nothing". This is because some Mailers will decide not to do work for some
# reason. For example, emailing a user too frequently. A nil to address is also considered
# "do nothing"
#
# It also adds an HTML part for the plain text body
#
require_dependency 'email/renderer'
require 'uri'
require 'net/smtp'

SMTP_CLIENT_ERRORS = [Net::SMTPFatalError, Net::SMTPSyntaxError]

module Email
  class Sender

    def initialize(message, email_type, user=nil)
      @message =  message
      @email_type = email_type
      @user = user
    end

    def send
      return if SiteSetting.disable_emails && @email_type.to_s != "admin_login"

      return if ActionMailer::Base::NullMail === @message
      return if ActionMailer::Base::NullMail === (@message.message rescue nil)

      return skip(I18n.t('email_log.message_blank'))    if @message.blank?
      return skip(I18n.t('email_log.message_to_blank')) if @message.to.blank?

      if @message.text_part
        return skip(I18n.t('email_log.text_part_body_blank')) if @message.text_part.body.to_s.blank?
      else
        return skip(I18n.t('email_log.body_blank')) if @message.body.to_s.blank?
      end

      @message.charset = 'UTF-8'

      opts = {}

      renderer = Email::Renderer.new(@message, opts)

      if @message.html_part
        @message.html_part.body = renderer.html
      else
        @message.html_part = Mail::Part.new do
          content_type 'text/html; charset=UTF-8'
          body renderer.html
        end
      end

      @message.parts[0].body = @message.parts[0].body.to_s.gsub(/\[\/?email-indent\]/, '')

      # Fix relative (ie upload) HTML links in markdown which do not work well in plain text emails.
      # These are the links we add when a user uploads a file or image.
      # Ideally we would parse general markdown into plain text, but that is almost an intractable problem.
      url_prefix = Discourse.base_url
      @message.parts[0].body = @message.parts[0].body.to_s.gsub(/<a class="attachment" href="(\/uploads\/default\/[^"]+)">([^<]*)<\/a>/, '[\2]('+url_prefix+'\1)')
      @message.parts[0].body = @message.parts[0].body.to_s.gsub(/<img src="(\/uploads\/default\/[^"]+)"([^>]*)>/, '![]('+url_prefix+'\1)')

      @message.text_part.content_type = 'text/plain; charset=UTF-8'

      # Set up the email log
      email_log = EmailLog.new(email_type: @email_type, to_address: to_address, user_id: @user.try(:id))

      host = Email::Sender.host_for(Discourse.base_url)

      topic_id = header_value('X-Discourse-Topic-Id')
      post_id = header_value('X-Discourse-Post-Id')
      reply_key = header_value('X-Discourse-Reply-Key')

      # always set a default Message ID from the host
      uuid = SecureRandom.uuid
      @message.header['Message-ID'] = "<#{uuid}@#{host}>"

      if topic_id.present?
        email_log.topic_id = topic_id

        incoming_email = IncomingEmail.find_by(post_id: post_id, topic_id: topic_id)

        incoming_message_id = nil
        incoming_message_id = "<#{incoming_email.message_id}>" if incoming_email.try(:message_id).present?

        topic_identifier = "<topic/#{topic_id}@#{host}>"
        post_identifier = "<topic/#{topic_id}/#{post_id}@#{host}>"

        @message.header['Message-ID'] = post_identifier
        @message.header['In-Reply-To'] = incoming_message_id || topic_identifier
        @message.header['References'] = topic_identifier

        topic = Topic.where(id: topic_id).first

        # http://www.ietf.org/rfc/rfc2919.txt
        if topic && topic.category && !topic.category.uncategorized?
          list_id = "<#{topic.category.name.downcase.gsub(' ', '-')}.#{host}>"

          # subcategory case
          if !topic.category.parent_category_id.nil?
            parent_category_name = Category.find_by(id: topic.category.parent_category_id).name
            list_id = "<#{topic.category.name.downcase.gsub(' ', '-')}.#{parent_category_name.downcase.gsub(' ', '-')}.#{host}>"
          end
        else
          list_id = "<#{host}>"
        end

        # http://www.ietf.org/rfc/rfc3834.txt
        @message.header['Precedence']   = 'list'
        @message.header['List-ID']      = list_id
        @message.header['List-Archive'] = topic.url if topic
      end

      if reply_key.present? && @message.header['Reply-To'] =~ /\<([^\>]+)\>/
        email = Regexp.last_match[1]
        @message.header['List-Post'] = "<mailto:#{email}>"
      end

      if SiteSetting.reply_by_email_address.present? && SiteSetting.reply_by_email_address["+"]
        email_log.bounce_key = SecureRandom.hex

        # WARNING: RFC claims you can not set the Return Path header, this is 100% correct
        # however Rails has special handling for this header and ends up using this value
        # as the Envelope From address so stuff works as expected
        @message.header[:return_path] = SiteSetting.reply_by_email_address.sub("%{reply_key}", "verp-#{email_log.bounce_key}")
      end

      email_log.post_id = post_id if post_id.present?
      email_log.reply_key = reply_key if reply_key.present?

      # Remove headers we don't need anymore
      @message.header['X-Discourse-Topic-Id']  = nil if topic_id.present?
      @message.header['X-Discourse-Post-Id']   = nil if post_id.present?
      @message.header['X-Discourse-Reply-Key'] = nil if reply_key.present?

      # Suppress images from short emails
      if SiteSetting.strip_images_from_short_emails &&
        @message.html_part.body.to_s.bytesize <= SiteSetting.short_email_length &&
        @message.html_part.body =~ /<img[^>]+>/
        style = Email::Styles.new(@message.html_part.body.to_s)
        @message.html_part.body = style.strip_avatars_and_emojis
      end

      email_log.message_id = @message.message_id

      begin
        @message.deliver_now
      rescue *SMTP_CLIENT_ERRORS => e
        return skip(e.message)
      end

      # Save and return the email log
      email_log.save!
      email_log
    end

    def to_address
      @to_address ||= begin
        to = @message.try(:to)
        to = to.first if Array === to
        to.presence || "no_email_found"
      end
    end

    def self.host_for(base_url)
      host = "localhost"
      if base_url.present?
        begin
          uri = URI.parse(base_url)
          host = uri.host.downcase if uri.host.present?
        rescue URI::InvalidURIError
        end
      end
      host
    end

    private

    def header_value(name)
      header = @message.header[name]
      return nil unless header
      header.value
    end

    def skip(reason)
      EmailLog.create!(
        email_type: @email_type,
        to_address: to_address,
        user_id: @user.try(:id),
        skipped: true,
        skipped_reason: "[Sender] #{reason}"
      )
    end

  end
end
