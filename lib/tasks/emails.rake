# frozen_string_literal: true

def process_popmail(popmail)
  begin
    mail_string = popmail.pop
    Email::Receiver.new(mail_string).process
  rescue
    putc "!"
  else
    putc "."
  end
end

desc "use this task to import a mailbox into Discourse"
task "emails:import" => :environment do
  begin
    unless SiteSetting.email_in
      puts "ERROR: you should enable the 'email_in' site setting before running this task"
      exit(1)
    end

    address  = ENV["ADDRESS"].presence || "pop.gmail.com"
    port     = (ENV["PORT"].presence || 995).to_i
    ssl      = (ENV["SSL"].presence || "1") == "1"
    username = ENV["USERNAME"].presence
    password = ENV["PASSWORD"].presence

    if username.blank?
      puts "ERROR: expecting USERNAME=<username> rake emails:import"
      exit(2)
    elsif password.blank?
      puts "ERROR: expecting PASSWORD=<password> rake emails:import"
      exit(3)
    end

    RateLimiter.disable

    mails_left = 1
    pop3 = Net::POP3.new(address, port)
    pop3.enable_ssl(max_version: OpenSSL::SSL::TLS1_2_VERSION) if ssl

    while mails_left > 0
      pop3.start(username, password) do |pop|
        pop.delete_all do |p|
          process_popmail(p)
        end
        mails_left = pop.n_mails
      end
    end

    puts "Done"
  rescue Net::POPAuthenticationError
    puts "AUTH EXCEPTION: please make sure your credentials are correct."
    exit(10)
  ensure
    RateLimiter.enable
  end
end

desc "Check if SMTP connection is successful and send test message"
task 'emails:test', [:email] => [:environment] do |_, args|
  email = args[:email]
  message = "OK"
  begin
    smtp = Discourse::Application.config.action_mailer.smtp_settings

    if smtp[:address].match(/smtp\.gmail\.com/)
      puts <<~STR
        #{smtp}
        ============================== WARNING ==============================

        Sending mail with Gmail is a violation of their terms of service.

        Sending with G Suite might work, but it is not recommended. For information see:
        https://meta.discourse.org/t/discourse-aws-ec2-g-suite-troubleshooting/62931?u=pfaffman

        ========================= CONTINUING TEST ============================
      STR
    end

    puts "Testing sending to #{email} using #{smtp[:address]}:#{smtp[:port]}, username:#{smtp[:user_name]} with #{smtp[:authentication]} auth."

    # We are not formatting the messages using EmailSettingsExceptionHandler here
    # because we are doing custom messages in the rake task with more details.
    EmailSettingsValidator.validate_smtp(
      host: smtp[:address],
      port: smtp[:port],
      domain: smtp[:domain] || 'localhost',
      username: smtp[:user_name],
      password: smtp[:password],
      authentication: smtp[:authentication] || 'plain'
    )
  rescue Exception => e

    if e.to_s.match(/execution expired/)
      message = <<~STR
        ======================================== ERROR ========================================
        Connection to port #{smtp[:port]} failed.
        ====================================== SOLUTION =======================================
        The most likely problem is that your server has outgoing SMTP traffic blocked.
        If you are using a service like Mailgun or Sendgrid, try using port 2525.
        =======================================================================================
      STR

    elsif e.to_s.match(/530.*STARTTLS/)
      # We can't run a preliminary test with STARTTLS, we'll just try sending the test email.
      message = "OK"

    elsif e.to_s.match(/535/)
      message = <<~STR
        ======================================== ERROR ========================================
                                          AUTHENTICATION FAILED

        #{e}

        ====================================== SOLUTION =======================================
        The most likely problem is that your SMTP username and/or Password is incorrect.
        Check them and try again.
        =======================================================================================
      STR

    elsif e.to_s.match(/Connection refused/)
      message = <<~STR
        ======================================== ERROR ========================================
                                          CONNECTION REFUSED

        #{e}

        ====================================== SOLUTION =======================================
        The most likely problem is that you have chosen the wrong port or a network problem is
        blocking access from the Docker container.

        Check the port and your networking configuration.
        =======================================================================================
      STR

    elsif e.to_s.match(/service not known/)
      message = <<~STR
        ======================================== ERROR ========================================
                                          SMTP SERVER NOT FOUND

        #{e}

        ====================================== SOLUTION =======================================
        The most likely problem is that the host name of your SMTP server is incorrect.
        Check it and try again.
        =======================================================================================
      STR

    else
      message = <<~STR
        ======================================== ERROR ========================================
                                            UNEXPECTED ERROR

        #{e}

        ====================================== SOLUTION =======================================
        This is not a common error. No recommended solution exists!

        Please report the exact error message above to https://meta.discourse.org/
        (And a solution, if you find one!)
        =======================================================================================
      STR
    end
  end
  if message == "OK"
    puts "SMTP server connection successful."
  else
    puts message
    exit
  end
  begin
    puts "Sending to #{email}. . . "
    email_log = Email::Sender.new(TestMailer.send_test(email), :test_message).send
    case email_log
    when SkippedEmailLog
      puts <<~STR
        Mail was not sent.

        Reason: #{email_log.reason}
      STR
    when EmailLog
      puts <<~STR
        Mail accepted by SMTP server.
        Message-ID: #{email_log.message_id}

        If you do not receive the message, check your SPAM folder
        or test again using a service like http://www.mail-tester.com/.

        If the message is not delivered it is not a problem with Discourse.
        Check the SMTP server logs for the above Message ID to see why it
        failed to deliver the message.
      STR
    when nil
      puts <<~STR
        Mail was not sent.

        Verify the status of the `disable_emails` site setting.
      STR
    else
      puts <<~STR
        SCRIPT BUG: Got back a #{email_log.class}
        #{email_log.inspect}

        Mail may or may not have been sent. Check the destination mailbox.
      STR
    end
  rescue => error
    puts "Sending mail failed."
    puts error.message
  end

  if SiteSetting.disable_emails != 'no'
    puts <<~STR

      ### WARNING
      The `disable_emails` site setting is currently set to #{SiteSetting.disable_emails}.
      Consider changing it to 'no' before performing any further troubleshooting.
    STR
  end
end
