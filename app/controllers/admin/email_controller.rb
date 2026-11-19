# frozen_string_literal: true

class Admin::EmailController < Admin::AdminController
  allow_when_archived :handle_mail
  skip_before_action :check_xhr, only: :preview_redirect

  def index
  end

  def server_settings
    data = { delivery_method: delivery_method, settings: delivery_settings }
    render_json_dump(data)
  end

  def test
    recipient = test_email_recipient!(:email_address)
    RateLimiter.new(
      current_user,
      "admin-email-test-send",
      10,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
    begin
      message = TestMailer.send_test(recipient)
      Email::Sender.new(message, :test_message).send

      render json: { sent_test_email_message: I18n.t("admin.email.sent_test") }
    rescue => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end
  end

  def preview
    preview = email_preview
    if preview.empty?
      render json: { subject: nil, html_content: "", text_content: "" }
    else
      render json: {
               subject: preview.message.subject,
               html_content: preview.renderer.html,
               text_content: preview.renderer.text,
             }
    end
  end

  def preview_redirect
    url = path("/admin/email/preview")
    url = "#{url}?#{request.query_string}" if request.query_string.present?
    redirect_to url, status: :moved_permanently
  end

  def preview_types
    render json: {
             message_types: Email::Preview.message_types,
             email_templates: Email::Preview.email_templates,
             branding_themes: Email::Preview.branding_themes,
           }
  end

  def advanced_test
    params.require(:email)

    receiver = Email::Receiver.new(params["email"])
    text, elided, format = receiver.select_body

    render json: success_json.merge!(text: text, elided: elided, format: format)
  end

  def send_preview
    recipient = test_email_recipient!(:email)
    preview = email_preview
    if SiteSetting.disable_emails == "yes" ||
         (SiteSetting.disable_emails == "non-staff" && !User.find_by_email(recipient)&.staff?)
      render json: {
               errors: [I18n.t("email_settings.preview_sends_disabled")],
             },
             status: :unprocessable_entity
      return
    end
    RateLimiter.new(
      current_user,
      "admin-email-preview-send",
      10,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!
    if preview.empty?
      render json: {
               errors: [I18n.t("email_settings.preview_empty")],
             },
             status: :unprocessable_entity
      return
    end
    begin
      delivery = preview.deliver_to(recipient)
      if delivery.is_a?(EmailLog)
        render json: success_json
      else
        render_json_error(delivery&.reason || I18n.t("email_settings.preview_sends_disabled"))
      end
    rescue => error
      render json: { errors: [error.message] }, status: :unprocessable_entity
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

  def test_email_recipient!(parameter)
    recipient = params.require(parameter)
    raise Discourse::InvalidParameters unless recipient.is_a?(String)
    recipient = recipient.strip

    if SiteSetting.restrict_admin_email_test_sends_to_self
      if !current_user.user_emails.where("lower(email) = ?", recipient.downcase).exists?
        raise Discourse::InvalidParameters.new(I18n.t("email_settings.test_email_restricted"))
      end
    end

    # Mail sends to every address in a list or comma-separated string, but the send checks look at one.
    raise Discourse::InvalidParameters unless Email.is_valid?(recipient)
    recipient
  end

  def email_preview
    params.require(:username)
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters.new(:username) if !user

    Email::Preview.new(
      user:,
      email_type: params[:email_type],
      locale: params[:locale],
      since: params[:last_seen_at],
      theme_id: params[:theme_id],
    )
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
