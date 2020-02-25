# frozen_string_literal: true

require 'net/pop'

module Jobs
  class PollMailbox < ::Jobs::Scheduled
    every SiteSetting.pop3_polling_period_mins.minutes
    sidekiq_options retry: false

    include Email::BuildEmailHelper

    def execute(args)
      @args = args
      poll_pop3 if should_poll?
    end

    def should_poll?
      return false if Rails.env.development? && ENV["POLL_MAILBOX"].nil?
      SiteSetting.pop3_polling_enabled?
    end

    def process_popmail(popmail)
      Email::Processor.process!(popmail.pop)
    end

    POLL_MAILBOX_TIMEOUT_ERROR_KEY ||= "poll_mailbox_timeout_error_key".freeze

    def poll_pop3
      pop3 = Net::POP3.new(SiteSetting.pop3_polling_host, SiteSetting.pop3_polling_port)

      if SiteSetting.pop3_polling_ssl
        if SiteSetting.pop3_polling_openssl_verify
          pop3.enable_ssl(max_version: OpenSSL::SSL::TLS1_2_VERSION)
        else
          pop3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
        end
      end

      pop3.start(SiteSetting.pop3_polling_username, SiteSetting.pop3_polling_password) do |pop|
        pop.each_mail do |p|
          process_popmail(p)
          p.delete if SiteSetting.pop3_polling_delete_from_server?
        end
      end
    rescue Net::OpenTimeout => e
      count = Discourse.redis.incr(POLL_MAILBOX_TIMEOUT_ERROR_KEY).to_i

      Discourse.redis.expire(
        POLL_MAILBOX_TIMEOUT_ERROR_KEY,
        SiteSetting.pop3_polling_period_mins.minutes * 3
      ) if count == 1

      if count > 3
        Discourse.redis.del(POLL_MAILBOX_TIMEOUT_ERROR_KEY)
        mark_as_errored!
        add_admin_dashboard_problem_message('dashboard.poll_pop3_timeout')
        Discourse.handle_job_exception(e, error_context(@args, "Connecting to '#{SiteSetting.pop3_polling_host}' for polling emails."))
      end
    rescue Net::POPAuthenticationError => e
      mark_as_errored!
      add_admin_dashboard_problem_message('dashboard.poll_pop3_auth_error')
      Discourse.handle_job_exception(e, error_context(@args, "Signing in to poll incoming emails."))
    end

    POLL_MAILBOX_ERRORS_KEY ||= "poll_mailbox_errors".freeze

    def self.errors_in_past_24_hours
      Discourse.redis.zremrangebyscore(POLL_MAILBOX_ERRORS_KEY, 0, 24.hours.ago.to_i)
      Discourse.redis.zcard(POLL_MAILBOX_ERRORS_KEY).to_i
    end

    def mark_as_errored!
      now = Time.now.to_i
      Discourse.redis.zadd(POLL_MAILBOX_ERRORS_KEY, now, now.to_s)
    end

    def add_admin_dashboard_problem_message(i18n_key)
      AdminDashboardData.add_problem_message(
        i18n_key,
        SiteSetting.pop3_polling_period_mins.minutes + 5.minutes
      )
    end

  end
end
