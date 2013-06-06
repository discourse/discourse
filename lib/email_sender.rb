#
# A helper class to send an email. It will also handle a nil message, which it considers
# to be "do nothing". This is because some Mailers will decide not to do work for some
# reason. For example, emailing a user too frequently. A nil to address is also considered
# "do nothing"
#
# It also adds an HTML part for the plain text body
#
require_dependency 'email_renderer'

class EmailSender

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

    renderer = EmailRenderer.new(@message, opts)

    @message.html_part = Mail::Part.new do
      content_type 'text/html; charset=UTF-8'
      body renderer.html
    end

    @message.text_part.content_type = 'text/plain; charset=UTF-8'
    @message.deliver

    to_address = @message.to
    to_address = to_address.first if to_address.is_a?(Array)

    EmailLog.create!(email_type: @email_type, to_address: to_address, user_id: @user.try(:id))
  end

end
