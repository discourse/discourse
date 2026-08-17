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
      return unless message_id = message.dig("mail", "messageId").presence
      return unless bounce_type = message.dig("bounce", "bounceType").presence

      return if !Email::Sns.allowed_topic_arn?(json["TopicArn"])
      return unless Email::Sns.authentic?(raw)

      Array(message.dig("bounce", "bouncedRecipients")).each do |r|
        email_log = EmailLog.find_by(message_id: message_id, to_address: r["emailAddress"])

        Email::Receiver.record_bounce(
          email_log,
          permanent: bounce_type != "Transient",
          bounce_error_code: r["status"],
        )
      end
    end
  end
end
