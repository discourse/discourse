# frozen_string_literal: true

class IncomingEmailDetailsSerializer < ApplicationSerializer
  attributes :error, :error_description, :rejection_message, :headers, :subject, :body

  def initialize(incoming_email, opts)
    super
    @error_string = incoming_email.error
    @mail = Mail.new(incoming_email.raw)
  end

  EMAIL_RECEIVER_ERROR_PREFIX = "Email::Receiver::"

  def error
    @error_string.presence || I18n.t("emails.incoming.unrecognized_error")
  end

  def include_error?
    !object.error.nil?
  end

  def error_description
    error_name = @error_string.sub(EMAIL_RECEIVER_ERROR_PREFIX, "").underscore
    I18n.t("emails.incoming.errors.#{error_name}")
  end

  def include_error_description?
    !object.error.nil? && @error_string && @error_string[EMAIL_RECEIVER_ERROR_PREFIX]
  end

  def headers
    @mail.header.to_s
  end

  def subject
    @mail.subject.presence || I18n.t("emails.incoming.no_subject")
  end

  def body
    body =
      begin
        @mail.text_part.decoded
      rescue StandardError
        nil
      end
    body ||=
      begin
        @mail.html_part.decoded
      rescue StandardError
        nil
      end
    body ||=
      begin
        @mail.body.decoded
      rescue StandardError
        nil
      end

    return I18n.t("emails.incoming.no_body") if body.blank?

    body
      .encode("utf-8", invalid: :replace, undef: :replace, replace: "")
      .strip
      .truncate_words(100, escape: false)
  end
end
