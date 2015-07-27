# kind of odd, but we need it, we also need to nuke usage of User from inside migrations
#  very poor form
user = User.find_by("id <> -1 and username_lower = 'system'")
if user
  user.username = UserNameSuggester.suggest("system")
  user.save
end

User.seed do |u|
  u.id = -1
  u.name = "system"
  u.username = "system"
  u.username_lower = "system"
  u.email = "no_email"
  u.password = SecureRandom.hex
  u.active = true
  u.admin = true
  u.moderator = true
  u.email_direct = false
  u.approved = true
  u.email_private_messages = false
  u.trust_level = TrustLevel[4]
end

Group.user_trust_level_change!(-1, TrustLevel[4])

# User for the smoke tests
if ENV["SMOKE"] == "1"
  smoke_user = User.seed do |u|
    u.id = 0
    u.name = "smoke_user"
    u.username = "smoke_user"
    u.username_lower = "smoke_user"
    u.email = "smoke_user@discourse.org"
    u.password = "P4ssw0rd"
    u.email_direct = false
    u.email_digests = false
    u.email_private_messages = false
    u.active = true
    u.approved = true
    u.approved_at = Time.now
    u.trust_level = TrustLevel[3]
  end.first

  EmailToken.seed do |et|
    et.id = 1
    et.user_id = smoke_user.id
    et.email = smoke_user.email
    et.confirmed = true
  end
end
