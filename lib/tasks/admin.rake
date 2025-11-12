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
