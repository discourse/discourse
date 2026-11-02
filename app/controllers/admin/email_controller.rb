# frozen_string_literal: true

class Admin::EmailController < Admin::AdminController
  allow_when_archived :handle_mail

  def index
  end

  def server_settings
    data = { delivery_method: delivery_method, settings: delivery_settings }
    render_json_dump(data)
  end

  def test
    params.require(:email_address)
    ensure_test_email_recipient!(params[:email_address])
    RateLimiter.new(
      current_user,
      "admin-email-test-send",
      10,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
    begin
      message = TestMailer.send_test(params[:email_address])
      Email::Sender.new(message, :test_message).send

      render json: { sent_test_email_message: I18n.t("admin.email.sent_test") }
    rescue => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def preview_digest
    params.require(:last_seen_at)
    params.require(:username)
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters unless user

    message =
      UserNotifications.digest(user, since: params[:last_seen_at], skip_unsubscribe_links: true)
    if message.body.to_s.blank? && message.text_part&.body.to_s.blank? &&
         message.html_part&.body.to_s.blank?
      render json: { html_content: "", text_content: "" }
    else
      renderer = Email::Renderer.new(message)
      render json: { html_content: renderer.html, text_content: renderer.text }
    end
  end

  def advanced_test
    params.require(:email)

    receiver = Email::Receiver.new(params["email"])
    text, elided, format = receiver.select_body

    render json: success_json.merge!(text: text, elided: elided, format: format)
  end

  def send_digest
    params.require(:last_seen_at)
    params.require(:username)
    params.require(:email)
    ensure_test_email_recipient!(params[:email])
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters unless user

    RateLimiter.new(
      current_user,
      "admin-email-preview-send",
      10,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
    message, skip_reason =
      UserNotifications.public_send(
        :digest,
        user,
        since: params[:last_seen_at],
        skip_unsubscribe_links: true,
      )

    if message
      message.to = params[:email]

      begin
        Email::Sender.new(message, :digest).send
        render json: success_json
      rescue => e
        render json: { errors: [e.message] }, status: :unprocessable_entity
      end
    else
      render json: { errors: skip_reason }
    end
  end

  # TODO (martin) Remove this in 3.7.0, this endpoint has been broken for years
  # and was used only in the public mail-receiver's fast rejection code,
  # which is removed in https://github.com/discourse/mail-receiver/pull/33
  def smtp_should_reject
    render json: { reject: false }
  end

  def handle_mail
    deprecated_email_param_used = false

    if params[:email_encoded].present?
      email_raw = Base64.strict_decode64(params[:email_encoded])
    elsif params[:email].present?
      deprecated_email_param_used = true
      email_raw = params[:email]
    else
      raise ActionController::ParameterMissing.new("email_encoded or email")
    end

    # If it isn't valid UTF-8, reinterpret as ISO-8859-1 so it can be serialized to JSON.
    email_raw = email_raw.dup.force_encoding("UTF-8")
    email_raw = email_raw.encode("UTF-8", "ISO-8859-1") if !email_raw.valid_encoding?

    Jobs.enqueue(:process_email, mail: email_raw, retry_on_rate_limit: true, source: "handle_mail")

    if deprecated_email_param_used
      warning =
        "warning: the email parameter is deprecated. all POST requests to this route should be sent with a base64 strict encoded email_encoded parameter instead. email has been received and is queued for processing"

      Discourse.deprecate(warning, drop_from: "3.3.0")

      render plain: warning
    else
      render plain: "email has been received and is queued for processing"
    end
  end

  private

  def ensure_test_email_recipient!(recipient)
    return if !SiteSetting.restrict_admin_email_test_sends_to_self

    normalized_recipient = recipient.to_s.strip.downcase
    return if current_user.user_emails.where("lower(email) = ?", normalized_recipient).exists?

    raise Discourse::InvalidParameters.new(I18n.t("email_settings.test_email_restricted"))
  end

  def delivery_settings
    action_mailer_settings.reject { |k, _| k == :password }.map { |k, v| { name: k, value: v } }
  end

  def delivery_method
    ActionMailer::Base.delivery_method
  end

  def action_mailer_settings
    ActionMailer::Base.public_send "#{delivery_method}_settings"
  end
end
