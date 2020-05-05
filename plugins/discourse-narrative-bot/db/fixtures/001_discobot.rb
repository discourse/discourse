# frozen_string_literal: true

discobot_username = 'discobot'
discobot_user_id = -2

def seed_primary_email(user_id)
  UserEmail.seed do |ue|
    ue.id = user_id
    ue.email = "discobot_email"
    ue.primary = true
    ue.user_id = user_id
  end
end

unless user = User.find_by(id: discobot_user_id)
  suggested_username = UserNameSuggester.suggest(discobot_username)

  seed_primary_email(discobot_user_id)

  User.seed do |u|
    u.id = discobot_user_id
    u.name = discobot_username
    u.username = suggested_username
    u.username_lower = suggested_username.downcase
    u.password = SecureRandom.hex
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[4]
  end
end

bot = User.find(discobot_user_id)

# ensure discobot has a primary email
unless bot.primary_email
  seed_primary_email(discobot_user_id)
  bot.reload
end

bot.update!(admin: true, moderator: false)

bot.user_option.update!(
  email_messages_level: UserOption.email_level_types[:never],
  email_level: UserOption.email_level_types[:never]
)

if !bot.user_profile.bio_raw
  bot.user_profile.update!(
    bio_raw: I18n.t('discourse_narrative_bot.bio', site_title: SiteSetting.title, discobot_username: bot.username)
  )
end

if !Rails.env.test? && (bot.user_avatar&.custom_upload_id.blank?)
  File.open(Rails.root.join("plugins", "discourse-narrative-bot", "assets", "images", "discobot.png"), 'r') do |file|
    UserAvatar.create_custom_avatar(bot, file, override_gravatar: true)
  end
end

Group.user_trust_level_change!(discobot_user_id, TrustLevel[4])
