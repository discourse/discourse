desc "Creates a forum administrator"
task "admin:create" => :environment do
  require 'highline/import'

  begin
    email = ask("Email:  ")
    existing_user = User.find_by_email(email)

    # check if user account already exixts
    if existing_user
      # user already exists, ask for password reset
      admin = existing_user
      reset_password = ask("User with this email already exists! Do you want to reset the password for this email? (Y/n)  ")
      if (reset_password == "" || reset_password.downcase == 'y')
        begin
          password = ask("Password:  ") {|q| q.echo = false}
          password_confirmation = ask("Repeat password:  ") {|q| q.echo = false}
        end while password != password_confirmation
        admin.password = password
      end
    else
      # create new user
      admin = User.new
      admin.email = email
      username_random = Random.new()
      admin.username = "admin_#{username_random.rand(9999)}"
      begin
        password = ask("Password:  ") {|q| q.echo = false}
        password_confirmation = ask("Repeat password:  ") {|q| q.echo = false}
      end while password != password_confirmation
      admin.password = password
    end

    # save/update user account
    saved = admin.save
    if !saved
      puts admin.errors.full_messages.join("\n")
      next
    end
  end while !saved

  if existing_user
    say("\nAccount updated successfully!")
  else
    say("\nAccount created successfully with username #{admin.username}")
  end

  # grant admin privileges
  grant_admin = ask("Do you want to grant Admin privileges to this account? (Y/n)  ")
  if (grant_admin == "" || grant_admin.downcase == 'y')
    admin.grant_admin!
    admin.change_trust_level!(TrustLevel.levels.max_by{|k, v| v}[0])
    admin.email_tokens.update_all  confirmed: true
    admin.activate

    say("\nYour account now has Admin privileges!")
  end

end
