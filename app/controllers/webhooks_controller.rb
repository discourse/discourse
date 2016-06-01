require "openssl"

class WebhooksController < ActionController::Base

  def mailgun
    # can't verify data without an API key
    return mailgun_failure if SiteSetting.mailgun_api_key.blank?

    # token is a random string of 50 characters
    token = params.delete("token")
    return mailgun_failure if token.blank? || token.size != 50

    # prevent replay attack
    key = "mailgun_token_#{token}"
    return mailgun_failure unless $redis.setnx(key, 1)
    $redis.expire(key, 8.hours)

    # ensure timestamp isn't too far from current time
    timestamp = params.delete("timestamp")
    return mailgun_failure if (Time.at(timestamp.to_i) - Time.now).abs > 1.hour.to_i

    # check the signature
    return mailgun_failure unless mailgun_verify(timestamp, token, params["signature"])

    handled = false
    event = params.delete("event")

    # only handle soft bounces, because hard bounces are also handled
    # by the "dropped" event and we don't want to increase bounce score twice
    # for the same message
    if event == "bounced".freeze && params["error"]["4."]
      handled = mailgun_process(params, Email::Receiver::SOFT_BOUNCE_SCORE)
    elsif event == "dropped".freeze
      handled = mailgun_process(params, Email::Receiver::HARD_BOUNCE_SCORE)
    end

    handled ? mailgun_success : mailgun_failure
  end

  def sendgrid
    params["_json"].each do |event|
      if event["event"] == "bounce".freeze
        if event["status"]["4."]
          sendgrid_process(event, Email::Receiver::SOFT_BOUNCE_SCORE)
        else
          sendgrid_process(event, Email::Receiver::HARD_BOUNCE_SCORE)
        end
      elsif event["event"] == "dropped".freeze
        sendgrid_process(event, Email::Receiver::HARD_BOUNCE_SCORE)
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

    def mailgun_process(params, bounce_score)
      return false if params["message-headers"].blank?

      return_path_header = params["message-headers"].first { |h| h[0] == "Return-Path".freeze }
      return false if return_path_header.blank?

      return_path = return_path_header[1]
      return false if return_path.blank?

      bounce_key = return_path[/\+verp-(\h{32})@/, 1]
      return false if bounce_key.blank?

      email_log = EmailLog.find_by(bounce_key: bounce_key)
      return false if email_log.nil?

      email_log.update_columns(bounced: true)
      Email::Receiver.update_bounce_score(email_log.user.email, bounce_score)

      true
    end

    def sendgrid_process(event, bounce_score)
      message_id = event["smtp-id"]
      return if message_id.blank?

      email_log = EmailLog.find_by(message_id: message_id.tr("<>", ""))
      return if email_log.nil?

      email_log.update_columns(bounced: true)
      Email::Receiver.update_bounce_score(email_log.user.email, bounce_score)
    end

end
