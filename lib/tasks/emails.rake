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

desc "use this task to import a mailbox into Disourse"
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
    pop3.enable_ssl if ssl

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

desc "Check if we can connect to the SMTP server"
task 'emails:test', [:email] => [:environment] do |_, args|
  email = args[:email]
  message = "OK"
  begin
    smtp=Discourse::Application.config.action_mailer.smtp_settings

    if smtp[:address].match(/smtp\.gmail\.com/)
      puts "

#{smtp}
============================== WARNING ==============================

Sending mail with Gmail is a violation of their terms of service.

Sending with G Suite might work, but it is not recommended. For information see:
https://meta.discourse.org/t/dscourse-aws-ec2-g-suite-troubleshoting/62931?u=pfaffman

========================= CONTINUING TEST ============================
"
    end

    puts "Testing sending to #{email} using #{smtp[:user_name]}:#{smtp[:password]}@#{smtp[:address]}:#{smtp[:port]}."

    Net::SMTP.start(smtp[:address], smtp[:port])
      .auth_login(smtp[:user_name], smtp[:password])
  rescue Exception => e





    if e.to_s.match(/execution expired/)
      message = "

======================================== ERROR ========================================
Connection to port #{ENV["DISCOURSE_SMTP_PORT"]} failed.
====================================== SOLUTION =======================================
The most likely problem is that your server has outgoing SMTP traffic blocked.
If you are using a service like Mailgun or Sendgrid, try using port 2525.
=======================================================================================

"
    elsif e.to_s.match(/535/)
      message = "

======================================== ERROR ========================================
                                  AUTHENTICATION FAILED

#{e}

====================================== SOLUTION =======================================
The most likely problem is that your SMTP username and/or Password is incorrect.
Check them and try again.
=======================================================================================

"
    elsif e.to_s.match(/Connection refused/)
      message = "

======================================== ERROR ========================================
                                  CONNECTION REFUSED

#{e}

====================================== SOLUTION =======================================
The most likely problem is that you have chosen the wrong port or a network problem is
blocking access from the Docker container.

Check the port and your networking configuration.
=======================================================================================

"
    elsif e.to_s.match(/service not known/)
      message = "

======================================== ERROR ========================================
                                  SMTP SERVER NOT FOUND

#{e}

====================================== SOLUTION =======================================
The most likely problem is that the host name of your SMTP server is incorrect.
Check it and try again.
=======================================================================================

"
    else
      message = "

======================================== ERROR ========================================
                                    UNEXPECTED ERROR

#{e}

====================================== SOLUTION =======================================
This is not a common error. No recommended solution exists!

Please report the exact error message above. (And a solution, if you find one!)
=======================================================================================

"
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
    Email::Sender.new(TestMailer.send_test(email), :test_message).send
  rescue
    puts "Sending mail failed."
  else
    puts "
Mail accepted by SMTP server.

If you do not receive the message, check your SPAM folder
or test again using a service like http://www.mail-tester.com/.

If the message is not delivered it is not a problem with Discourse.

Check the SMTP server logs to see why it failed to deliver the message.

"
  end
end
