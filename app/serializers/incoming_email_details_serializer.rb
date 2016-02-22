class IncomingEmailDetailsSerializer < ApplicationSerializer

  attributes :error,
             :error_description,
             :return_path,
             :date,
             :from,
             :to,
             :cc,
             :message_id,
             :references,
             :in_reply_to,
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

  def return_path
    @mail.return_path
  end

  def date
    @mail.date
  end

  def from
    @mail.from.first.downcase
  end

  def to
    @mail.to.map(&:downcase)
  end

  def cc
    @mail.cc.map(&:downcase) if @mail.cc.present?
  end

  def message_id
    @mail.message_id
  end

  def references
    references = Email::Receiver.extract_references(@mail.references)
    references.delete(@mail.in_reply_to) if references
    references
  end

  def in_reply_to
    @mail.in_reply_to
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
