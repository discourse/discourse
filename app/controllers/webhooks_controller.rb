require "openssl"

class WebhooksController < ActionController::Base

  def mailgun
    # can't verify data without an API key
    return mailgun_failure if SiteSetting.mailgun_api_key.blank?

    # token is a random string of 50 characters
    token = params["token"]
    return mailgun_failure if token.blank? || token.size != 50

    # prevent replay attack
    key = "mailgun_token_#{token}"
    return mailgun_failure unless $redis.setnx(key, 1)
    $redis.expire(key, 10.minutes)

    # ensure timestamp isn't too far from current time
    timestamp = params["timestamp"]
    return mailgun_failure if (Time.at(timestamp.to_i) - Time.now).abs > 24.hours.to_i

    # check the signature
    return mailgun_failure unless mailgun_verify(timestamp, token, params["signature"])

    event = params["event"]
    message_id = params["Message-Id"].tr("<>", "")

    # only handle soft bounces, because hard bounces are also handled
    # by the "dropped" event and we don't want to increase bounce score twice
    # for the same message
    if event == "bounced".freeze && params["error"]["4."]
      process_bounce(message_id, Email::Receiver::SOFT_BOUNCE_SCORE)
    elsif event == "dropped".freeze
      process_bounce(message_id, Email::Receiver::HARD_BOUNCE_SCORE)
    end

    mailgun_success
  end

  def sendgrid
    events = params["_json"] || [params]
    events.each do |event|
      message_id = (event["smtp-id"] || "").tr("<>", "")
      if event["event"] == "bounce".freeze
        if event["status"]["4."]
          process_bounce(message_id, Email::Receiver::SOFT_BOUNCE_SCORE)
        else
          process_bounce(message_id, Email::Receiver::HARD_BOUNCE_SCORE)
        end
      elsif event["event"] == "dropped".freeze
        process_bounce(message_id, Email::Receiver::HARD_BOUNCE_SCORE)
      end
    end

    render nothing: true, status: 200
  end

  def mailjet
    events = params["_json"] || [params]
    events.each do |event|
      message_id = event["CustomID"]
      if event["event"] == "bounce".freeze
        if event["hard_bounce"]
          process_bounce(message_id, Email::Receiver::HARD_BOUNCE_SCORE)
        else
          process_bounce(message_id, Email::Receiver::SOFT_BOUNCE_SCORE)
        end
      end
    end

    render nothing: true, status: 200
  end

  def mandrill
    events = params["mandrill_events"]
    events.each do |event|
      message_id = event["msg"]["metadata"]["message_id"] rescue nil
      next unless message_id

      case event["event"]
      when "hard_bounce"
        process_bounce(message_id, Email::Receiver::HARD_BOUNCE_SCORE)
      when "soft_bounce"
        process_bounce(message_id, Email::Receiver::SOFT_BOUNCE_SCORE)
      end
    end

    render nothing: true, status: 200
  end

  private

    def mailgun_failure
      render nothing: true, status: 406
    end

    def mailgun_success
      render nothing: true, status: 200
    end

    def mailgun_verify(timestamp, token, signature)
      digest = OpenSSL::Digest::SHA256.new
      data = "#{timestamp}#{token}"
      signature == OpenSSL::HMAC.hexdigest(digest, SiteSetting.mailgun_api_key, data)
    end

    def process_bounce(message_id, bounce_score)
      return if message_id.blank?

      email_log = EmailLog.find_by(message_id: message_id)
      return if email_log.nil?

      email_log.update_columns(bounced: true)
      Email::Receiver.update_bounce_score(email_log.user.email, bounce_score)
    end

end
