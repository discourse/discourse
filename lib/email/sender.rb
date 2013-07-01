#
# A helper class to send an email. It will also handle a nil message, which it considers
# to be "do nothing". This is because some Mailers will decide not to do work for some
# reason. For example, emailing a user too frequently. A nil to address is also considered
# "do nothing"
#
# It also adds an HTML part for the plain text body
#
require_dependency 'email/renderer'

module Email
  class Sender

    def initialize(message, email_type, user=nil)
      @message =  message
      @email_type = email_type
      @user = user
    end

    def send
      return if @message.blank?
      return if @message.to.blank?
      return if @message.body.blank?

      @message.charset = 'UTF-8'

      opts = {}

      # Only use the html template on digest emails
      opts[:html_template] = true if (@email_type == 'digest')

      renderer = Email::Renderer.new(@message, opts)

      @message.html_part = Mail::Part.new do
        content_type 'text/html; charset=UTF-8'
        body renderer.html
      end

      @message.text_part.content_type = 'text/plain; charset=UTF-8'

      # Set up the email log
      to_address = @message.to
      to_address = to_address.first if to_address.is_a?(Array)
      email_log = EmailLog.new(email_type: @email_type,
                               to_address: to_address,
                               user_id: @user.try(:id))

      add_header_to_log('X-Discourse-Reply-Key', email_log, :reply_key)
      add_header_to_log('X-Discourse-Post-Id', email_log, :post_id)
      add_header_to_log('X-Discourse-Topic-Id', email_log, :topic_id)

      # Remove headers we don't need anymore
      @message.header['X-Discourse-Topic-Id'] = nil
      @message.header['X-Discourse-Post-Id'] = nil
      @message.header['X-Discourse-Reply-Key'] = nil

      @message.deliver

      # Save and return the email log
      email_log.save!
      email_log

    end

    private

    def add_header_to_log(name, email_log, email_log_field)
      header = @message.header[name]
      return unless header

      val = header.value
      email_log[email_log_field] = val if val.present?
    end

  end
end