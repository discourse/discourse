# frozen_string_literal: true

module SmtpRetryable
  extend ActiveSupport::Concern

  sidekiq_retry_in do |count, exception|
    # retry in an hour when SMTP server is busy
    # or use default sidekiq retry formula. returning
    # nil/0 will trigger the default sidekiq
    # retry formula
    #
    # See https://github.com/mperham/sidekiq/blob/3330df0ee37cfd3e0cd3ef01e3e66b584b99d488/lib/sidekiq/job_retry.rb#L216-L234
    case exception.wrapped
    when Net::SMTPServerBusy
      return 1.hour + (rand(30) * (count + 1))
    end

    0
  end
end
