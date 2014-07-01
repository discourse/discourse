#
# Connects to a mailbox and checks for replies
#
require 'net/pop'
require_dependency 'email/receiver'
require_dependency 'email/sender'
require_dependency 'email/message_builder'

module Jobs
  class PollMailbox < Jobs::Scheduled
    every SiteSetting.pop3s_polling_period_mins.minutes
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
      rescue => e
        message_template = nil
        case e
          when Email::Receiver::UserNotSufficientTrustLevelError
            message_template = :email_reject_trust_level
          when Email::Receiver::UserNotFoundError
            message_template = :email_reject_no_account
          when Email::Receiver::EmptyEmailError
            message_template = :email_reject_empty
          when Email::Receiver::EmailUnparsableError
            message_template = :email_reject_parsing
          when Email::Receiver::EmailLogNotFound
            message_template = :email_reject_reply_key
          when ActiveRecord::Rollback
            message_template = :email_reject_post_error
          else
            message_template = nil
        end

        if message_template
          # inform the user about the rejection
          message = Mail::Message.new(mail_string)
          client_message = RejectionMailer.send_rejection(message.from, message.body, message.to, message_template)
          Email::Sender.new(client_message, message_template).send
        else
          Discourse.handle_exception(e, { code: "unknown error for incoming email", mail: mail_string} )
        end
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
      Discourse.handle_exception(e, { code: "signing in for incoming email" } )
    end

  end
end
