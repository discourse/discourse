desc "Creates a forum administrator"
task "admin:create" => :environment do
  require 'highline/import'
  begin
    admin = User.new
    admin.email = ask("Email:")
    admin.username = "admin"
    begin
      password = ask("Password:") {|q| q.echo = false}
      password_confirmation = ask("Repeat password:") {|q| q.echo = false}
    end while password != password_confirmation
    admin.password = password
    # admin.email_confirmed = true
    saved = admin.save
    if !saved
      puts admin.errors.full_messages.join("\n")
      next
    end
  end while !saved
  admin.grant_admin!
  admin.change_trust_level!(TrustLevel.levels.max_by{|k, v| v}[0])
  admin.email_tokens.update_all  confirmed: true
end
