user = User.where("id <> -1 and username_lower = 'community'").first
if user
  user.username = UserNameSuggester.suggest('community')
  user.save
end

User.seed do |u|
  u.id = -1
  u.name = 'Community'
  u.username = 'community'
  u.username_lower = 'community'
  u.email = 'no_email'
  u.password = SecureRandom.hex
  u.bio_raw = 'I am a community user, I clean up the forum and make sure it runs well.'
  u.active = true
  u.admin = true
  u.moderator = true
  u.email_direct = false
  u.approved = true
  u.email_private_messages = false
end
