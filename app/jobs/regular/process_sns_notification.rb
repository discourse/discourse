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
      # SES assigns its own mail.messageId; the Message-ID stored in EmailLog is
      # only present when the notification includes the original headers.
      message_ids = [
        original_message_id(message),
        message.dig("mail", "messageId"),
      ].compact_blank.uniq
      return if message_ids.empty?
      return unless bounce_type = message.dig("bounce", "bounceType").presence

      return if !Email::Sns.allowed_topic_arn?(json["TopicArn"])
      return unless Email::Sns.authentic?(raw)

      Array(message.dig("bounce", "bouncedRecipients")).each do |r|
        email_log = EmailLog.find_by(message_id: message_ids, to_address: r["emailAddress"])
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

    def original_message_id(message)
      header =
        Array(message.dig("mail", "headers")).find do |h|
          h.is_a?(Hash) && h["name"].to_s.casecmp?("Message-ID")
        end

      Email::MessageIdService.message_id_clean(header&.dig("value").to_s.strip)
    end
  end
end
