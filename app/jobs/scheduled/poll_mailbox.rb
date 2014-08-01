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
      @args = args
      if SiteSetting.pop3s_polling_enabled?
        poll_pop3s
      end
    end

    def handle_mail(mail)
      begin
        mail_string = mail.pop
        Email::Receiver.new(mail_string).process
      rescue => e
        handle_failure(mail_string, e)
      ensure
        mail.delete
      end
    end

    def handle_failure(mail_string, e)
      template_args = {}
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
        when Email::Receiver::InvalidPost
          if e.message.length < 6
            message_template = :email_reject_post_error
          else
            message_template = :email_reject_post_error_specified
            template_args[:post_error] = e.message
          end

        else
          message_template = nil
      end

      if message_template
        # inform the user about the rejection
        message = Mail::Message.new(mail_string)
        template_args[:former_title] = message.subject
        template_args[:destination] = message.to

        client_message = RejectionMailer.send_rejection(message_template, message.from, template_args)
        Email::Sender.new(client_message, message_template).send
      else
        Discourse.handle_exception(e, error_context(@args, "Unrecognized error type when processing incoming email", mail: mail_string))
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
      Discourse.handle_exception(e, error_context(@args, "Signing in to poll incoming email"))
    end

  end
end
