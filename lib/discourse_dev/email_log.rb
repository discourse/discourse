# frozen_string_literal: true

require "discourse_dev/record"
require "faker"

module DiscourseDev
  class EmailLog < Record
    def initialize
      super(::EmailLog, DiscourseDev.config.email_logs[:count])
    end

    def create_sent!
      ::EmailLog.create!(email_log_data)
    end

    def create_bounced!
      bounce_key = SecureRandom.hex
      email_local_part, email_domain = SiteSetting.notification_email.split("@")
      bounced_to_address = "#{email_local_part}+verp-#{bounce_key}@#{email_domain}"
      bounce_data =
        email_log_data.merge(
          to_address: bounced_to_address,
          bounced: true,
          bounce_key: bounce_key,
          bounce_error_code: "5.0.0",
        )

      # Bounced email logs require a matching incoming email record
      ::IncomingEmail.create!(
        incoming_email_data.merge(to_addresses: bounced_to_address, is_bounce: true),
      )
      ::EmailLog.create!(bounce_data)
    end

    def create_rejected!
      ::IncomingEmail.create!(incoming_email_data)
    end

    def email_log_data
      {
        to_address: User.random.email,
        email_type: :digest,
        user_id: User.random.id,
        raw: Faker::Lorem.paragraph,
      }
    end

    def incoming_email_data
      user = User.random
      subject = Faker::Lorem.sentence
      email_content = <<-EMAIL
        Return-Path: #{user.email}
        From: #{user.email}
        Date: #{Date.today}
        Mime-Version: "1.0"
        Content-Type: "text/plain"
        Content-Transfer-Encoding: "7bit"

        #{Faker::Lorem.paragraph}
      EMAIL

      {
        user_id: user.id,
        from_address: user.email,
        raw: email_content,
        error: Faker::Lorem.sentence,
        rejection_message: I18n.t("emails.incoming.errors.bounced_email_error"),
      }
    end

    def populate!
      @count.times { create_sent! }
      @count.times { create_bounced! }
      @count.times { create_rejected! }
    end
  end
end
