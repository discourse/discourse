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
