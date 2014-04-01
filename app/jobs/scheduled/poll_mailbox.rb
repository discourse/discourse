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
        @message = Mail::Message.new(mail_string)
        clientMessage = RejectionMailer.send_trust_level(@message.from, @message.body)
        email_sender = Email::Sender.new(clientMessage, :email_reject_trust_level)
        email_sender.send
      rescue Email::Receiver::ProcessingError
        # all other ProcessingErrors are ok to be dropped
      rescue StandardError => e
        # Inform Admins about error
        GroupMessage.create(Group[:admins].name, :email_error_notification,
            {limit_once_per: false, message_params: {source: mail, error: e}})
      ensure
        mail.delete
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
            handle_mail(mail)
          end
        end
      end
    end

  end
end
