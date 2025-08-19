# frozen_string_literal: true

class Admin::EmailController < Admin::AdminController
  def index
  end

  def server_settings
    data = { delivery_method: delivery_method, settings: delivery_settings }
    render_json_dump(data)
  end

  def test
    params.require(:email_address)
    begin
      message = TestMailer.send_test(params[:email_address])
      Email::Sender.new(message, :test_message).send

      render json: { sent_test_email_message: I18n.t("admin.email.sent_test") }
    rescue => e
      render json: { errors: [e.message] }, status: 422
    end
  end

  def preview_digest
    params.require(:last_seen_at)
    params.require(:username)
    user = User.find_by_username(params[:username])
    raise Discourse::InvalidParameters unless user

    renderer = Email::Renderer.new(UserNotifications.digest(user, since: params[:last_seen_at]))
    render json: MultiJson.dump(html_content: renderer.html, text_content: renderer.text)
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
    user = User.find_by_username(params[:username])

    message, skip_reason =
      UserNotifications.public_send(:digest, user, since: params[:last_seen_at])

    if message
      message.to = params[:email]
      begin
        Email::Sender.new(message, :digest).send
        render json: success_json
      rescue => e
        render json: { errors: [e.message] }, status: 422
      end
    else
      render json: { errors: skip_reason }
    end
  end

  def smtp_should_reject
    params.require(:from)
    params.require(:to)
    # These strings aren't localized; they are sent to an anonymous SMTP user.
    if !User.with_email(Email.downcase(params[:from])).exists? && !SiteSetting.enable_staged_users
      render json: {
               reject: true,
               reason: "Mail from your address is not accepted. Do you have an account here?",
             }
    elsif Email::Receiver.check_address(Email.downcase(params[:to])).nil?
      render json: {
               reject: true,
               reason:
                 "Mail to this address is not accepted. Check the address and try to send again?",
             }
    else
      render json: { reject: false }
    end
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

    retry_count = 0

    begin
      Jobs.enqueue(
        :process_email,
        mail: email_raw,
        retry_on_rate_limit: true,
        source: "handle_mail",
      )
    rescue JSON::GeneratorError, Encoding::UndefinedConversionError => e
      if retry_count == 0
        email_raw = email_raw.force_encoding("iso-8859-1").encode("UTF-8")
        retry_count += 1
        retry
      else
        raise e
      end
    end

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
