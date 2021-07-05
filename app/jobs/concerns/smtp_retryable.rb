# frozen_string_literal: true

module SmtpRetryable
  extend ActiveSupport::Concern

  sidekiq_retry_in do |count, exception|
    # retry in an hour when SMTP server is busy
    # or use default sidekiq retry formula. returning
    # nil/0 will trigger the default sidekiq
    # retry formula
    case exception.wrapped
    when Net::SMTPServerBusy
      return 1.hour + (rand(30) * (count + 1))
    end

    0
  end
end
