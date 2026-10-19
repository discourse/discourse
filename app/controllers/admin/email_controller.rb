# frozen_string_literal: true

class Admin::EmailController < Admin::AdminController
  allow_when_archived :handle_mail

  EMAIL_PREVIEW_SENDER_TYPES = {
    "digest" => :digest,
    "password_reset" => :forgot_password,
    "password_reset_code" => :email_login_code,
    "email_login_code" => :email_login_code,
    "signup" => :signup,
    "activation_reminder" => :activation_reminder,
    "email_login" => :email_login,
    "admin_login" => :admin_login,
    "account_created" => :account_created,
    "confirm_new_email" => :confirm_new_email,
    "test_email" => :test_message,
  }.freeze
  TEMPLATE_PREVIEW_PREFIX = "template:"
  PREVIEW_PASSWORD_RESET_TOKEN = "preview-password-reset-token"
  PREVIEW_EMAIL_TOKEN = "preview-email-token"
  PREVIEW_LOGIN_CODE = "PREVIEW"

  def index
  end

  def server_settings
    data = { delivery_method: delivery_method, settings: delivery_settings }
    render_json_dump(data)
  end

  def test
    params.require(:email_address)
    ensure_test_email_recipient!(params[:email_address])
    begin
      message = TestMailer.send_test(params[:email_address])
      Email::Sender.new(message, :test_message).send

      render json: { sent_test_email_message: I18n.t("admin.email.sent_test") }
    rescue => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def preview_digest
    params.require(:username)
    email_type = preview_email_type
    params.require(:last_seen_at) if email_type == "digest"
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters unless user

    locale = preview_locale(user)
    message = preview_message(user, email_type, locale)
    if preview_message_empty?(message)
      render json: MultiJson.dump(subject: nil, html_content: "", text_content: "")
      return
    end

    renderer = Email::Renderer.new(message, locale:)
    render json:
             MultiJson.dump(
               subject: message.subject,
               html_content: renderer.html,
               text_content: renderer.text,
             )
  end

  def preview_types
    templates =
      Admin::EmailTemplatesController.email_keys.map do |key|
        serializer = AdminEmailTemplateSerializer.new(key)
        { id: key, title: serializer.title }
      end

    render json: { email_templates: templates }
  end

  def advanced_test
    params.require(:email)

    receiver = Email::Receiver.new(params["email"])
    text, elided, format = receiver.select_body

    render json: success_json.merge!(text: text, elided: elided, format: format)
  end

  def send_digest
    params.require(:username)
    params.require(:email)
    ensure_test_email_recipient!(params[:email])
    email_type = preview_email_type
    params.require(:last_seen_at) if email_type == "digest"
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters unless user

    locale = preview_locale(user)
    message, skip_reason = send_preview_message(user, email_type, locale)

    if message
      message.to = params[:email]

      begin
        I18n.with_locale(locale) do
          Email::Sender.new(message, preview_sender_type(email_type)).send
        end
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

  def preview_message_empty?(message)
    message.body.to_s.blank? && message.text_part&.body.to_s.blank? &&
      message.html_part&.body.to_s.blank?
  end

  def ensure_test_email_recipient!(recipient)
    return if !SiteSetting.restrict_admin_email_test_sends_to_self

    normalized_recipient = recipient.to_s.strip.downcase
    return if current_user.user_emails.where("lower(email) = ?", normalized_recipient).exists?

    raise Discourse::InvalidParameters.new(I18n.t("email_settings.test_email_restricted"))
  end

  def preview_locale(user)
    locale = params[:locale].presence || user.effective_locale
    if locale.blank? || LocaleSiteSetting.supported_locales.exclude?(locale)
      raise Discourse::InvalidParameters.new(:locale)
    end

    locale
  end

  def preview_email_type
    email_type = params[:email_type].presence || "digest"
    return email_type if EMAIL_PREVIEW_SENDER_TYPES.key?(email_type)
    return email_type if valid_template_preview?(email_type)

    raise Discourse::InvalidParameters.new(:email_type)
  end

  def preview_message(user, email_type, locale)
    if template_key = preview_template_key(email_type)
      return template_preview_message(user, template_key, locale)
    end

    case email_type
    when "digest"
      UserNotifications.digest(
        user,
        since: params[:last_seen_at],
        skip_unsubscribe_links: true,
        locale:,
      )
    when "password_reset"
      UserNotifications.forgot_password(user, email_token: PREVIEW_PASSWORD_RESET_TOKEN, locale:)
    when "password_reset_code"
      EmailLoginCodeMailer.send_code(user.email, PREVIEW_LOGIN_CODE, password_reset: true, locale:)
    when "email_login_code"
      EmailLoginCodeMailer.send_code(user.email, PREVIEW_LOGIN_CODE, locale:)
    when "signup"
      UserNotifications.signup(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "activation_reminder"
      UserNotifications.activation_reminder(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "email_login"
      UserNotifications.email_login(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "admin_login"
      UserNotifications.admin_login(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "account_created"
      UserNotifications.account_created(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "confirm_new_email"
      UserNotifications.confirm_new_email(user, email_token: PREVIEW_EMAIL_TOKEN, locale:)
    when "test_email"
      TestMailer.send_test(user.email, locale:)
    end
  end

  def preview_sender_type(email_type)
    return :test_message if preview_template_key(email_type)

    EMAIL_PREVIEW_SENDER_TYPES.fetch(email_type)
  end

  def send_preview_message(user, email_type, locale)
    if email_type == "digest"
      UserNotifications.public_send(
        :digest,
        user,
        since: params[:last_seen_at],
        skip_unsubscribe_links: true,
        locale:,
      )
    else
      [preview_message(user, email_type, locale), nil]
    end
  end

  def valid_template_preview?(email_type)
    template_key = preview_template_key(email_type)
    template_key.present? && Admin::EmailTemplatesController.email_keys.include?(template_key)
  end

  def preview_template_key(email_type)
    if email_type.start_with?(TEMPLATE_PREVIEW_PREFIX)
      email_type.delete_prefix(TEMPLATE_PREVIEW_PREFIX)
    end
  end

  def template_preview_message(user, template_key, locale)
    subject = template_preview_value("#{template_key}.subject_template", locale)
    body = template_preview_value("#{template_key}.text_body_template", locale)
    TestMailer.send_template_preview(user.email, subject:, body:, locale:)
  end

  def template_preview_value(translation_key, locale)
    value = I18n.t(translation_key, locale:)
    value = value[:other] || value["other"] if value.is_a?(Hash)
    raise Discourse::InvalidParameters.new(:email_type) if !value.is_a?(String)

    value
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
