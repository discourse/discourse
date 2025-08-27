# frozen_string_literal: true

desc "invite an admin to this discourse instance"
task "admin:invite", [:email] => [:environment] do |_, args|
  email = args[:email]
  if !email || email !~ /@/
    puts "ERROR: Expecting rake admin:invite[some@email.com]"
    exit 1
  end

  unless user = User.find_by_email(email)
    puts "Creating new account!"
    user = User.new(email: email)
    user.password = SecureRandom.hex
    user.username = UserNameSuggester.suggest(user.email)
  end

  user.active = true
  user.save!

  puts "Granting admin!"
  user.grant_admin!
  user.change_trust_level!(1) if user.trust_level < 1

  user.email_tokens.update_all confirmed: true

  puts "Sending email!"
  email_token =
    user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:password_reset])
  Jobs.enqueue(
    :user_email,
    type: "account_created",
    user_id: user.id,
    email_token: email_token.token,
  )
end

desc "Creates a forum administrator"
task "admin:create" => :environment do
  require "highline/import"

  begin
    email = ask("Email:  ")
    existing_user = User.find_by_email(email)

    # check if user account already exists
    if existing_user
      # user already exists, ask for password reset
      admin = existing_user
      reset_password =
        ask(
          "User with this email already exists! Do you want to reset the password for this email? (Y/n)  ",
        )
      if (reset_password == "" || reset_password.downcase == "y")
        begin
          password = ask("Password:  ") { |q| q.echo = false }
          password_confirmation = ask("Repeat password:  ") { |q| q.echo = false }
          passwords_match = password == password_confirmation

          say("Passwords don't match, try again...") unless passwords_match
        end while !passwords_match
        admin.password = password
      end
    else
      # create new user
      admin = User.new
      admin.email = email
      admin.username = UserNameSuggester.suggest(admin.email)
      begin
        if ENV["RANDOM_PASSWORD"] == "1"
          password = password_confirmation = SecureRandom.hex
        else
          password = ask("Password:  ") { |q| q.echo = false }
          password_confirmation = ask("Repeat password:  ") { |q| q.echo = false }
        end

        passwords_match = password == password_confirmation

        say("Passwords don't match, try again...") unless passwords_match
      end while !passwords_match
      admin.password = password
    end

    admin.name = ask("Full name:  ") if SiteSetting.full_name_requirement == "required_at_signup" &&
      admin.name.blank?

    # save/update user account
    saved = admin.save
    say(admin.errors.full_messages.join("\n")) unless saved
  end while !saved

  say "\nEnsuring account is active!"
  admin.active = true
  admin.save

  if existing_user
    say("\nAccount updated successfully!")
  else
    say("\nAccount created successfully with username #{admin.username}")
  end

  # grant admin privileges
  grant_admin = ask("Do you want to grant Admin privileges to this account? (Y/n)  ")
  if (grant_admin == "" || grant_admin.downcase == "y")
    admin.grant_admin!
    admin.change_trust_level!(1) if admin.trust_level < 1
    admin.email_tokens.update_all confirmed: true
    admin.activate

    say("\nYour account now has Admin privileges!")
  end
end

desc "Register this Discourse instance with Discourse ID"
task "admin:register_discourse_id" => :environment do
  require "highline/import"

  begin
    puts
    puts "=== Discourse ID Registration ==="
    puts

    if SiteSetting.discourse_id_client_id.present? &&
         SiteSetting.discourse_id_client_secret.present?
      puts "⚠️  This site is already registered with Discourse ID."
      puts "   Client ID: #{SiteSetting.discourse_id_client_id}"
      puts

      force = ask("Do you want to re-register? This will replace existing credentials. (y/N): ")
      if force.downcase != "y"
        puts "Registration cancelled."
        exit 0
      end

      puts "Proceeding with forced re-registration..."
      force_param = true
    else
      puts "🔗 This will register your Discourse instance with Discourse ID."
      puts "   Provider URL: #{SiteSetting.discourse_id_provider_url.presence || "https://id.discourse.com"}"
      puts "   Site Title: #{SiteSetting.title}"
      puts "   Site URL: #{Discourse.base_url}"
      puts

      confirm = ask("Continue with registration? (Y/n): ")
      if confirm.downcase == "n"
        puts "Registration cancelled."
        exit 0
      end

      force_param = false
    end

    puts
    puts "🚀 Starting registration process..."

    result = DiscourseId::Register.call(params: { force: force_param })

    if result.success?
      puts
      puts "✅ Registration successful!"
      puts "   Client ID: #{SiteSetting.discourse_id_client_id}"
      puts "   Discourse ID is now enabled: #{SiteSetting.enable_discourse_id}"
      puts
      puts "🎉 Your Discourse instance is now registered with Discourse ID!"
      puts "   Users can now use Discourse ID to log in to your site."
    else
      puts
      puts "❌ Registration failed!"
      puts "   Error: #{result.error}" if result.error
      puts "   Please check your network connection and try again."
      puts "   If the problem persists, contact support."
      exit 1
    end
  rescue Interrupt
    puts
    puts "Registration cancelled by user."
    exit 1
  rescue => e
    puts
    puts "❌ An unexpected error occurred:"
    puts "   #{e.class}: #{e.message}"
    puts "   Please try again or contact support if the problem persists."
    exit 1
  end
end
