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
            else
                @message = Mail::Message.new(mail.pop)
                # One for you (mod), and one for me (sender)
                GroupMessage.create(Group[:moderators].name, :email_reject_notification, {limit_once_per: false, message_params: {from: @message.from, body: @message.body}})
                clientMessage = RejectionMailer.send_rejection(@message.from, @message.body)
                Email::Sender.new(clientMessage, :email_reject_notification).send
            end
          end
        end
      end
    end

  end
end
