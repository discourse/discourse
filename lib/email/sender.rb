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
      return skip(I18n.t('email_log.message_blank')) if @message.blank?
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

      @message.text_part.content_type = 'text/plain; charset=UTF-8'

      # Set up the email log
      email_log = EmailLog.new(email_type: @email_type,
                               to_address: to_address,
                               user_id: @user.try(:id))


      host = Email::Sender.host_for(Discourse.base_url)

      topic_id = header_value('X-Discourse-Topic-Id')
      post_id = header_value('X-Discourse-Post-Id')
      reply_key = header_value('X-Discourse-Reply-Key')

      if topic_id.present?
        email_log.topic_id = topic_id

        topic_identifier = "<topic/#{topic_id}@#{host}>"
        @message.header['In-Reply-To'] = topic_identifier
        @message.header['References'] = topic_identifier

        # http://www.ietf.org/rfc/rfc2919.txt
        list_id = "<topic.#{topic_id}.#{host}>"
        @message.header['List-ID'] = list_id

        topic = Topic.where(id: topic_id).first
        @message.header['List-Archive'] = topic.url if topic
      end

      if reply_key.present?

        if @message.header['Reply-To'] =~ /\<([^\>]+)\>/
          email = Regexp.last_match[1]
          @message.header['List-Post'] = "<mailto:#{email}>"
        end
      end

      email_log.post_id = post_id if post_id.present?
      email_log.reply_key = reply_key if reply_key.present?

      # Remove headers we don't need anymore
      @message.header['X-Discourse-Topic-Id'] = nil
      @message.header['X-Discourse-Post-Id'] = nil
      @message.header['X-Discourse-Reply-Key'] = nil

      begin
        @message.deliver
      rescue *SMTP_CLIENT_ERRORS => e
        return skip(e.message)
      end

      # Save and return the email log
      email_log.save!
      email_log
    end

    def to_address
      @to_address ||= begin
        to = @message ? @message.to : nil
        to.is_a?(Array) ? to.first : to
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
      EmailLog.create(email_type: @email_type,
                      to_address: to_address,
                      user_id: @user.try(:id),
                      skipped: true,
                      skipped_reason: reason)
    end

  end
end
