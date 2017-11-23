discobot_username = 'discobot'

def seed_primary_email
  UserEmail.seed do |ue|
    ue.id = -2
    ue.email = "discobot_email"
    ue.primary = true
    ue.user_id = -2
  end
end

unless user = User.find_by(id: -2)
  suggested_username = UserNameSuggester.suggest(discobot_username)

  seed_primary_email

  User.seed do |u|
    u.id = -2
    u.name = discobot_username
    u.username = suggested_username
    u.username_lower = suggested_username.downcase
    u.password = SecureRandom.hex
    u.active = true
    u.approved = true
    u.trust_level = TrustLevel[4]
  end

  # TODO Pull the user avatar from that thread for now. In the future, pull it from a local file or from some central discobot repo.
  if !Rails.env.test?
    begin
      UserAvatar.import_url_for_user(
        "https://cdn.discourse.org/dev/uploads/default/original/2X/e/edb63d57a720838a7ce6a68f02ba4618787f2299.png",
        User.find(-2),
        override_gravatar: true
      )
    rescue
      # In case the avatar can't be downloaded, don't fail seed
    end
  end
end

bot = User.find(-2)

# ensure discobot has a primary email
unless bot.primary_email
  seed_primary_email
  bot.reload
end

bot.update!(admin: true, moderator: false)

bot.user_option.update!(
  email_private_messages: false,
  email_direct: false
)

if !bot.user_profile.bio_raw
  bot.user_profile.update!(
    bio_raw: I18n.t('discourse_narrative_bot.bio', site_title: SiteSetting.title, discobot_username: bot.username)
  )
end

Group.user_trust_level_change!(-2, TrustLevel[4])
