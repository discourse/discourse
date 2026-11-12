# frozen_string_literal: true

module Jobs
  class ProcessSnsNotification < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless raw = args[:raw].presence
      return unless json = args[:json].presence
      return unless message = json["Message"].presence

      message =
        begin
          JSON.parse(message)
        rescue JSON::ParserError
          nil
        end

      return unless message && message["notificationType"] == "Bounce"
      return unless message_id = original_message_id(message["mail"])
      return unless bounce_type = message.dig("bounce", "bounceType").presence

      return if !Email::Sns.allowed_topic_arn?(json["TopicArn"])
      return unless Email::Sns.authentic?(raw)

      Array(message.dig("bounce", "bouncedRecipients")).each do |r|
        email_log = EmailLog.find_by(message_id: message_id, to_address: r["emailAddress"])
        next if email_log.nil? || email_log.bounced?

        email_log.update!(bounced: true, bounce_error_code: r["status"])

        next if email_log.user&.email.blank?

        if email_log.user.user_stat.bounce_score.to_s.start_with?("4.") ||
             bounce_type == "Transient"
          Email::Receiver.update_bounce_score(email_log.user.email, SiteSetting.soft_bounce_score)
        else
          Email::Receiver.update_bounce_score(email_log.user.email, SiteSetting.hard_bounce_score)
        end
      end
    end

    private

    def original_message_id(mail)
      header =
        Array(mail&.dig("headers")).find { |entry| entry["name"].to_s.casecmp?("Message-ID") }
      message_id = header&.dig("value").presence || mail&.dig("commonHeaders", "messageId").presence
      # Provider-assigned IDs do not identify the original message stored in EmailLog.
      Email::MessageIdService.message_id_clean(message_id.strip) if message_id
    end
  end
end
