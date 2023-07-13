# frozen_string_literal: true

discobot_username = "discobot"

def seed_primary_email
  UserEmail.seed do |ue|
    ue.id = DiscourseNarrativeBot::BOT_USER_ID
    ue.email = "discobot_email"
    ue.primary = true
    ue.user_id = DiscourseNarrativeBot::BOT_USER_ID
  end
end

unless user = User.find_by(id: DiscourseNarrativeBot::BOT_USER_ID)
  suggested_username = UserNameSuggester.suggest(discobot_username)

  seed_primary_email

  User.seed do |u|
    u.id = DiscourseNarrativeBot::BOT_USER_ID
    u.name = discobot_username
    u.username = suggested_username
    u.username_lower = suggested_username.downcase
    u.password = SecureRandom.hex
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[4]
  end
end

bot = User.find(DiscourseNarrativeBot::BOT_USER_ID)

# ensure discobot has a primary email
unless bot.primary_email
  seed_primary_email
  bot.reload
end

bot.update!(admin: true, moderator: false)

bot.create_user_option! if !bot.user_option

bot.user_option.update!(
  email_messages_level: UserOption.email_level_types[:never],
  email_level: UserOption.email_level_types[:never],
)

bot.create_user_profile! if !bot.user_profile

if !bot.user_profile.bio_raw
  bot.user_profile.update!(bio_raw: I18n.t("discourse_narrative_bot.bio"))
end

Group.user_trust_level_change!(DiscourseNarrativeBot::BOT_USER_ID, TrustLevel[4])
