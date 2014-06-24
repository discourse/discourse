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
      rescue => e
        # inform the user about the rejection
        message = Mail::Message.new(mail_string)
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
            nil
        end

        if message_template
          # Send message to the user
          client_message = RejectionMailer.send_rejection(message.from, message.body, message_template.to_s, "#{e.message}\n\n#{e.backtrace.join("\n")}")
          Email::Sender.new(client_message, message_template).send
        else
          Rails.logger.error e

          # If not known type, inform admins about the error
          data = { limit_once_per: false, message_params: { from: message.from, source: message.body, error: "#{e.message}\n\n#{e.backtrace.join("\n")}" }}
          GroupMessage.create(Group[:admins].name, :email_error_notification, data)
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
      # inform admins about the error (1 message per hour to prevent too much SPAM)
      data = { limit_once_per: 1.hour, message_params: { error: e }}
      GroupMessage.create(Group[:admins].name, :email_error_notification, data)
    end

  end
end
