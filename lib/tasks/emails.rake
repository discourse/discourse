# frozen_string_literal: true

def process_popmail(popmail)
  begin
    mail_string = popmail.pop
    Email::Receiver.new(mail_string).process
  rescue StandardError
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

    address = ENV["ADDRESS"].presence || "pop.gmail.com"
    port = (ENV["PORT"].presence || 995).to_i
    ssl = (ENV["SSL"].presence || "1") == "1"
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
        pop.delete_all { |p| process_popmail(p) }
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
task "emails:test", [:email] => [:environment] do |_, args|
  email = args[:email]
  message = "OK"

  def textwidth
    @textwidth ||=
      begin
        IO.console.winsize[1]
      rescue StandardError
        80
      end
  end

  def make_warning_message(warning)
    <<~EOT
      #{" WARNING ".center(textwidth, "=")}
      #{warning}\
      #{"=" * textwidth}
    EOT
  end

  def make_error_message(error, solution)
    <<~EOT
      #{" ERROR ".center(textwidth, "=")}
      #{error}\
      #{" SOLUTION ".center(textwidth, "=")}
      #{solution}\
      #{"=" * textwidth}
    EOT
  end

  begin
    smtp = Discourse::Application.config.action_mailer.smtp_settings

    puts make_warning_message(<<~WARN) + "\n" if smtp[:address].match(/smtp\.gmail\.com/)
          Sending mail with Gmail is a violation of their terms of service.

          Sending with G Suite might work, but it is not recommended.
          For further information see: https://meta.discourse.org/t/62931

          Current settings:
          #{smtp.compact}

          Continuing…
        WARN

    puts "Testing sending to #{email} using #{smtp[:address]}:#{smtp[:port]}, username:#{smtp[:user_name] || "(none)"} with #{smtp[:authentication] || "no"} auth."

    # We are not formatting the messages using EmailSettingsExceptionHandler here
    # because we are doing custom messages in the rake task with more details.
    EmailSettingsValidator.validate_smtp(
      host: smtp[:address],
      port: smtp[:port],
      domain: smtp[:domain] || "localhost",
      username: smtp[:user_name],
      password: smtp[:password],
      authentication: smtp[:authentication],
    )
  rescue Exception => e
    message =
      case e
      when ArgumentError
        make_error_message(<<~ERR, <<~SOL)
        #{e.class}: #{e.message.strip}
        ERR
        The combination of SMTP parameters is invalid - see the above error message for the reason.

        If you need assistance, please report the relevant SMTP environment variables
        and the exact error message above to https://meta.discourse.org/
        SOL
      when Net::SMTPAuthenticationError
        case e.message
        when /530.*STARTTLS/
          make_error_message(<<~ERR, <<~SOL)
          Your mail server has refused to accept credentials over an unencrypted connection.
          #{e.class}: #{e.message.strip}
          ERR
          If you have disabled STARTTLS (DISCOURSE_SMTP_ENABLE_START_TLS=false), remove it.
          SOL
        else
          make_error_message(<<~ERR, <<~SOL)
          Your mail server has refused your credentials as invalid:
          #{e.class}: #{e.message.strip}
          ERR
          Check your credentials for the mail server to verify they are correct:
          Username: #{smtp[:user_name]}
          Password: #{smtp[:password][..3]}… (truncated to four characters)
          SOL
        end
      when Errno::ECONNREFUSED
        make_error_message(<<~ERR, <<~SOL)
        Connection to port #{smtp[:port]} failed:
        #{e.class}: #{e.message.strip}
        ERR
        Your server has outgoing SMTP traffic blocked, or your connection attempt is explicitly blocked by your network.

        If you are using a external SMTP service (such as Mailgun or Sendgrid),
        review their service documentation to find an alternative port such as 2525.
        SOL
      when Errno::ENETUNREACH
        make_error_message(<<~ERR, <<~SOL)
        Connection to port #{smtp[:port]} failed:
        #{e.class}: #{e.message.strip}
        ERR
        Check your server connectivity. The server may actually be unreachable, or you may have chosen the
        wrong port, or a network problem is preventing access from the Docker container.
        SOL
      when Net::OpenTimeout
        make_error_message(<<~ERR, <<~SOL)
        Connection timeout while making the initial connection
        #{e.class}: #{e.message.strip}
        ERR
        The server may not actually be reachable, or your traffic may be silently dropped.

        If you are using a external SMTP service (such as Mailgun or Sendgrid),
        review their service documentation to find an alternative port such as 2525.
        SOL
      when Socket::ResolutionError
        make_error_message(<<~ERR, <<~SOL)
        SMTP server not found!
        #{e.class}: #{e.message.strip}
        ERR
        The most likely problem is that the host name of your SMTP server is incorrect.
        Check it and try again.
        SOL
      when OpenSSL::SSL::SSLError
        case e.message
        when /certificate verify failed/
          make_error_message(<<~ERR, <<~SOL)
          Encountered a certificate verification error while connecting to the mail server.
          #{e.class}: #{e.message.strip}
          ERR
          Check the SMTP server certificate. If the certificate is self-signed or from a private authority,
          consider setting DISCOURSE_SMTP_OPENSSL_VERIFY_MODE=none to disable verification.

          If you need assistance, please report the relevant SMTP environment variables
          and the exact error message above to https://meta.discourse.org/
          SOL
        else
          make_error_message(<<~ERR, <<~SOL)
          OpenSSL error encountered:
          #{e.class}: #{e.message.strip}
          ERR
          An unexpected error from openssl was encountered. Review the above output for clues.

          If you need assistance, please report the relevant SMTP environment variables
          and the exact error message above to https://meta.discourse.org/
          SOL
        end
      else
        make_error_message(<<~ERR, <<~SOL)
        UNKNOWN ERROR!
        #{e.class}: #{e.message.strip}
        ERR
        This is not a common error. No recommended solution exists!

        Please report the exact error message above to https://meta.discourse.org/
        (And a solution, if you find one!)
        SOL
      end
  end

  if message == "OK"
    puts "SMTP server connection successful."
  else
    puts message
    exit 1
  end

  begin
    puts "Sending to #{email}…"
    email_log = Email::Sender.new(TestMailer.send_test(email), :test_message).send
    case email_log
    when SkippedEmailLog
      puts make_error_message(<<~ERR, <<~SOL)
        Mail was not sent.
        Reason: #{email_log.reason.strip}
        ERR
        Review the reason for the failure and address it with the server owner.
        SOL
    when EmailLog
      puts <<~TEXT
        Mail accepted by SMTP server.
        Message-ID: #{email_log.message_id}

        If you do not receive the message, check your SPAM folder
        or test again using a service like http://www.mail-tester.com/.

        If the message is not delivered it is not a problem with Discourse.
        Check the SMTP server logs for the above Message ID to see why it
        failed to deliver the message.
      TEXT
    when nil
      puts make_error_message(<<~ERR, <<~SOL)
        Mail was not sent.
        ERR
        Verify the status of the `disable_emails` site setting.
        SOL
    else
      puts make_error_message(<<~ERR, <<~SOL)
        SCRIPT BUG: Got back a #{email_log.class}
        #{email_log.inspect}
        ERR
        Mail may or may not have been sent. Check the destination mailbox.
        Post this output to https://meta.discourse.org/ for assistance.
        SOL
    end
  rescue => e
    puts make_error_message(<<~ERR, <<~SOL)
      Sending mail failed:
      #{e.class}: #{e.message.strip}
      ERR
      Post this output to https://meta.discourse.org/ for assistance.
      SOL
  end

  puts make_warning_message(<<~WARN) if SiteSetting.disable_emails != "no"
      The `disable_emails` site setting is currently set to #{SiteSetting.disable_emails}.
      Consider changing it to 'no' before performing any further troubleshooting.
    WARN
end

desc "run this to fix users associated to emails mirrored from a mailman mailing list"
task "emails:fix_mailman_users" => :environment do
  if !SiteSetting.enable_staged_users
    puts "Please enable staged users first"
    exit 1
  end

  def find_or_create_user(email, name)
    user = nil

    User.transaction do
      unless user = User.find_by_email(email)
        username = UserNameSuggester.sanitize_username(name) if name.present?
        username = UserNameSuggester.suggest(username.presence || email)
        name = name.presence || User.suggest_name(email)

        begin
          user = User.create!(email: email, username: username, name: name, staged: true)
        rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        end
      end
    end

    user
  end

  IncomingEmail
    .includes(:user, :post)
    .where("raw LIKE '%X-Mailman-Version: %'")
    .find_each do |ie|
      next if ie.post.blank?

      mail = Mail.new(ie.raw)
      email, name = Email::Receiver.extract_email_address_and_name_from_mailman(mail)

      if email.blank? || email == ie.user.email
        putc "."
      elsif new_owner = find_or_create_user(email, name)
        PostOwnerChanger.new(
          post_ids: [ie.post_id],
          topic_id: ie.post.topic_id,
          new_owner: new_owner,
          acting_user: Discourse.system_user,
          skip_revision: true,
        ).change_owner!
        putc "#"
      else
        putc "X"
      end
    end
  nil
end
