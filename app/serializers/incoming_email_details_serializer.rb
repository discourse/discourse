class IncomingEmailDetailsSerializer < ApplicationSerializer

  attributes :error,
             :error_description,
             :rejection_message,
             :headers,
             :subject,
             :body

  def initialize(incoming_email, opts)
    super
    @error_string = incoming_email.error
    @mail = Mail.new(incoming_email.raw)
  end

  EMAIL_RECEIVER_ERROR_PREFIX = "Email::Receiver::".freeze

  def error
    @error_string
  end

  def error_description
    error_name = @error_string.sub(EMAIL_RECEIVER_ERROR_PREFIX, "").underscore
    I18n.t("emails.incoming.errors.#{error_name}")
  end

  def include_error_description?
    @error_string[EMAIL_RECEIVER_ERROR_PREFIX]
  end

  def headers
    @mail.header.to_s
  end

  def subject
    @mail.subject.presence || "(no subject)"
  end

  def body
    body   = @mail.text_part.decoded rescue nil
    body ||= @mail.html_part.decoded rescue nil
    body ||= @mail.body.decoded      rescue nil
    body.strip.truncate_words(100, escape: false)
  end

end
