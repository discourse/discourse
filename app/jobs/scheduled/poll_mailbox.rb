#
# Connects to a mailbox and checks for replies
#
require 'net/pop'
require_dependency 'email/receiver'

module Jobs
  class PollMailbox < Jobs::Scheduled
    recurrence { minutely }
    sidekiq_options retry: false

    def execute(args)
      if SiteSetting.pop3s_polling_enabled?
        poll_pop3s
      end
    end

    def poll_pop3s
      Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      Net::POP3.start(SiteSetting.pop3s_polling_host,
                      SiteSetting.pop3s_polling_port,
                      SiteSetting.pop3s_polling_username,
                      SiteSetting.pop3s_polling_password) do |pop|
        unless pop.mails.empty?
          pop.each do |mail|
            if Email::Receiver.new(mail.pop).process == Email::Receiver.results[:processed]
              mail.delete
            end
          end
        end
      end
    end

  end
end
