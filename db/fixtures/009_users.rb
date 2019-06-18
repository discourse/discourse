# frozen_string_literal: true

# kind of odd, but we need it, we also need to nuke usage of User from inside migrations
#  very poor form
user = User.find_by("id <> -1 and username_lower = 'system'")
if user
  user.username = UserNameSuggester.suggest("system")
  user.save
end

UserEmail.seed do |ue|
  ue.id = -1
  ue.email = "no_email"
  ue.primary = true
  ue.user_id = -1
end

User.seed do |u|
  u.id = -1
  u.name = "system"
  u.username = "system"
  u.username_lower = "system"
  u.password = SecureRandom.hex
  u.active = true
  u.admin = true
  u.moderator = true
  u.approved = true
  u.trust_level = TrustLevel[4]
end

UserOption.where(user_id: -1).update_all(
  email_messages_level: UserOption.email_level_types[:never],
  email_level: UserOption.email_level_types[:never]
)

Group.user_trust_level_change!(-1, TrustLevel[4])

# User for the smoke tests
if ENV["SMOKE"] == "1"
  UserEmail.seed do |ue|
    ue.id = 0
    ue.email = "smoke_user@discourse.org"
    ue.primary = true
    ue.user_id = 0
  end

  smoke_user = User.seed do |u|
    u.id = 0
    u.name = "smoke_user"
    u.username = "smoke_user"
    u.username_lower = "smoke_user"
    u.password = "P4ssw0rd"
    u.active = true
    u.approved = true
    u.approved_at = Time.now
    u.trust_level = TrustLevel[3]
  end.first

  UserOption.where(user_id: smoke_user.id).update_all(
    email_digests: false,
    email_messages_level: UserOption.email_level_types[:never],
    email_level: UserOption.email_level_types[:never]
  )

  EmailToken.where(user_id: smoke_user.id).update_all(confirmed: true)
end
