#
# Connects to a mailbox and checks for replies
#
require 'net/pop'
require_dependency 'email/receiver'
require_dependency 'email/sender'
require_dependency 'email/message_builder'

module Jobs
  class PollMailbox < Jobs::Scheduled
    every 5.minutes
    sidekiq_options retry: false
    include Email::BuildEmailHelper

    def execute(args)
      if SiteSetting.pop3s_polling_enabled?
        poll_pop3s
      end
    end

    def handle_mail(mail)
      begin
        mail_string = mail.pop
        Email::Receiver.new(mail_string).process
      rescue Email::Receiver::UserNotSufficientTrustLevelError
        # inform the user about the rejection
        message = Mail::Message.new(mail_string)
        client_message = RejectionMailer.send_trust_level(message.from, message.body)
        Email::Sender.new(client_message, :email_reject_trust_level).send
      rescue Email::Receiver::ProcessingError
        # all other ProcessingErrors are ok to be dropped
      rescue StandardError => e
        # inform admins about the error
        data = { limit_once_per: false, message_params: { source: mail, error: e }}
        GroupMessage.create(Group[:admins].name, :email_error_notification, data)
      ensure
        mail.delete
      end
    end

    def poll_pop3s
      if !SiteSetting.pop3s_polling_insecure
        Net::POP3.enable_ssl(OpenSSL::SSL::VERIFY_NONE)
      end
      Net::POP3.start(SiteSetting.pop3s_polling_host,
                      SiteSetting.pop3s_polling_port,
                      SiteSetting.pop3s_polling_username,
                      SiteSetting.pop3s_polling_password) do |pop|
        unless pop.mails.empty?
          pop.each do |mail|
            handle_mail(mail)
          end
        end
        pop.finish
      end
    rescue Net::POPAuthenticationError => e
      # inform admins about the error (1 message per hour to prevent too much SPAM)
      data = { limit_once_per: 1.hour, message_params: { error: e }}
      GroupMessage.create(Group[:admins].name, :email_error_notification, data)
    end

  end
end
