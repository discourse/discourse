# frozen_string_literal: true

require "openssl"

class WebhooksController < ActionController::Base
  skip_before_action :verify_authenticity_token

  def mailgun
    return mailgun_failure if SiteSetting.mailgun_api_key.blank?

    params["event-data"] ? handle_mailgun_new(params) : handle_mailgun_legacy(params)
  end

  def sendgrid
    events = params["_json"] || [params]
    events.each do |event|
      message_id = Email::MessageIdService.message_id_clean((event["smtp-id"] || ""))
      to_address = event["email"]
      error_code = event["status"]
      if event["event"] == "bounce"
        if error_code[Email::SMTP_STATUS_TRANSIENT_FAILURE]
          process_bounce(message_id, to_address, SiteSetting.soft_bounce_score, error_code)
        else
          process_bounce(message_id, to_address, SiteSetting.hard_bounce_score, error_code)
        end
      elsif event["event"] == "dropped"
        process_bounce(message_id, to_address, SiteSetting.hard_bounce_score, error_code)
      end
    end

    success
  end

  def mailjet
    events = params["_json"] || [params]
    events.each do |event|
      message_id = event["CustomID"]
      to_address = event["email"]
      if event["event"] == "bounce"
        if event["hard_bounce"]
          process_bounce(message_id, to_address, SiteSetting.hard_bounce_score)
        else
          process_bounce(message_id, to_address, SiteSetting.soft_bounce_score)
        end
      end
    end

    success
  end

  def mandrill
    events = JSON.parse(params["mandrill_events"])
    events.each do |event|
      message_id = event.dig("msg", "metadata", "message_id")
      to_address = event.dig("msg", "email")
      error_code = event.dig("msg", "diag")

      case event["event"]
      when "hard_bounce"
        process_bounce(message_id, to_address, SiteSetting.hard_bounce_score, error_code)
      when "soft_bounce"
        process_bounce(message_id, to_address, SiteSetting.soft_bounce_score, error_code)
      end
    end

    success
  end

  def mandrill_head
    # Mandrill sends a HEAD request to validate the webhook before saving
    # Rails interprets it as a GET request
    success
  end

  def postmark
    # see https://postmarkapp.com/developer/webhooks/bounce-webhook#bounce-webhook-data
    # and https://postmarkapp.com/developer/api/bounce-api#bounce-types

    message_id = params["MessageID"]
    to_address = params["Email"]
    type = params["Type"]
    case type
    when "HardBounce", "SpamNotification", "SpamComplaint"
      process_bounce(message_id, to_address, SiteSetting.hard_bounce_score)
    when "SoftBounce"
      process_bounce(message_id, to_address, SiteSetting.soft_bounce_score)
    end

    success
  end

  def sparkpost
    events = params["_json"] || [params]
    events.each do |event|
      message_event = event.dig("msys", "message_event")
      next unless message_event

      message_id   = message_event.dig("rcpt_meta", "message_id")
      to_address   = message_event["rcpt_to"]
      bounce_class = message_event["bounce_class"]
      next unless bounce_class

      bounce_class = bounce_class.to_i

      # bounce class definitions: https://support.sparkpost.com/customer/portal/articles/1929896
      if bounce_class < 80
        if bounce_class == 10 || bounce_class == 25 || bounce_class == 30
          process_bounce(message_id, to_address, SiteSetting.hard_bounce_score)
        else
          process_bounce(message_id, to_address, SiteSetting.soft_bounce_score)
        end
      end
    end

    success
  end

  def aws
    raw  = request.raw_post
    json = JSON.parse(raw)

    case json["Type"]
    when "SubscriptionConfirmation"
      Jobs.enqueue(:confirm_sns_subscription, raw: raw, json: json)
    when "Notification"
      Jobs.enqueue(:process_sns_notification, raw: raw, json: json)
    end

    success
  end

  private

  def mailgun_failure
    render body: nil, status: 406
  end

  def success
    render body: nil, status: 200
  end

  def valid_mailgun_signature?(token, timestamp, signature)
    # token is a random 50 characters string
    return false if token.blank? || token.size != 50

    # prevent replay attacks
    key = "mailgun_token_#{token}"
    return false unless Discourse.redis.setnx(key, 1)
    Discourse.redis.expire(key, 10.minutes)

    # ensure timestamp isn't too far from current time
    return false if (Time.at(timestamp.to_i) - Time.now).abs > 12.hours.to_i

    # check the signature
    signature == OpenSSL::HMAC.hexdigest("SHA256", SiteSetting.mailgun_api_key, "#{timestamp}#{token}")
  end

  def handle_mailgun_legacy(params)
    return mailgun_failure unless valid_mailgun_signature?(params["token"], params["timestamp"], params["signature"])

    event = params["event"]
    message_id = Email::MessageIdService.message_id_clean(params["Message-Id"])
    to_address = params["recipient"]
    error_code = params["code"]

    # only handle soft bounces, because hard bounces are also handled
    # by the "dropped" event and we don't want to increase bounce score twice
    # for the same message
    if event == "bounced" && params["error"][Email::SMTP_STATUS_TRANSIENT_FAILURE]
      process_bounce(message_id, to_address, SiteSetting.soft_bounce_score, error_code)
    elsif event == "dropped"
      process_bounce(message_id, to_address, SiteSetting.hard_bounce_score, error_code)
    end

    success
  end

  def handle_mailgun_new(params)
    signature = params["signature"]
    return mailgun_failure unless valid_mailgun_signature?(signature["token"], signature["timestamp"], signature["signature"])

    data = params["event-data"]
    error_code = params.dig("delivery-status", "code")
    message_id = data.dig("message", "headers", "message-id")
    to_address = data["recipient"]
    severity = data["severity"]

    if data["event"] == "failed"
      if severity == "temporary"
        process_bounce(message_id, to_address, SiteSetting.soft_bounce_score, error_code)
      elsif severity == "permanent"
        process_bounce(message_id, to_address, SiteSetting.hard_bounce_score, error_code)
      end
    end

    success
  end

  def process_bounce(message_id, to_address, bounce_score, bounce_error_code = nil)
    return if message_id.blank? || to_address.blank?

    email_log = EmailLog.find_by(message_id: message_id, to_address: to_address)
    return if email_log.nil?

    email_log.update_columns(bounced: true, bounce_error_code: bounce_error_code)
    return if email_log.user.nil? || email_log.user.email.blank?

    Email::Receiver.update_bounce_score(email_log.user.email, bounce_score)
  end

end
