# frozen_string_literal: true

# name: discourse-narrative-bot
# about: Introduces staff to Discourse
# version: 1.0
# authors: Nick Sahler, Alan Tan
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-narrative-bot

enabled_site_setting :discourse_narrative_bot_enabled
hide_plugin

require_relative "lib/discourse_narrative_bot/welcome_post_type_site_setting"
register_asset "stylesheets/discourse-narrative-bot.scss"
register_asset "fonts/GreatVibes-Regular.ttf"

module ::DiscourseNarrativeBot
  PLUGIN_NAME = "discourse-narrative-bot".freeze
  BOT_USER_ID = -2
end

require_relative "lib/discourse_narrative_bot/engine"

after_initialize do
  if Rails.env.test?
    ::SiteSetting.defaults.tap do |s|
      # disable plugins
      if ENV["LOAD_PLUGINS"] == "1"
        s.set_regardless_of_locale(:discourse_narrative_bot_enabled, false)
      end
    end
  end

  SeedFu.fixture_paths << Rails
    .root
    .join("plugins", "discourse-narrative-bot", "db", "fixtures")
    .to_s

  Mime::Type.register "image/svg+xml", :svg

  RailsMultisite::ConnectionManagement.safe_each_connection do
    if SiteSetting.discourse_narrative_bot_enabled
      # Disable welcome message because that is what the bot is supposed to replace.
      SiteSetting.send_welcome_message = false

      certificate_path = "#{Discourse.base_url}/discobot/certificate.svg"
      if !SiteSetting.allowed_iframes.include?(certificate_path)
        SiteSetting.allowed_iframes =
          SiteSetting.allowed_iframes.split("|").append(certificate_path).join("|")
      end
    end
  end

  self.add_model_callback(User, :after_destroy) { DiscourseNarrativeBot::Store.remove(self.id) }

  self.on(:user_created) do |user|
    if SiteSetting.discourse_narrative_bot_welcome_post_delay == 0 && !user.staged
      user.enqueue_bot_welcome_post
    end
  end

  self.on(:user_first_logged_in) do |user|
    user.enqueue_bot_welcome_post if SiteSetting.discourse_narrative_bot_welcome_post_delay > 0
  end

  self.on(:user_unstaged) { |user| user.enqueue_bot_welcome_post }

  self.add_to_class(:user, :enqueue_bot_welcome_post) do
    return if SiteSetting.disable_discourse_narrative_bot_welcome_post

    delay = SiteSetting.discourse_narrative_bot_welcome_post_delay

    case SiteSetting.discourse_narrative_bot_welcome_post_type
    when "new_user_track"
      if enqueue_narrative_bot_job? && !manually_disabled_discobot?
        Jobs.enqueue_in(
          delay,
          :narrative_init,
          user_id: self.id,
          klass: DiscourseNarrativeBot::NewUserNarrative.to_s,
        )
      end
    when "welcome_message"
      Jobs.enqueue_in(delay, :send_default_welcome_message, user_id: self.id)
    end
  end

  self.add_to_class(:user, :manually_disabled_discobot?) { user_option&.skip_new_user_tips }

  self.add_to_class(:user, :enqueue_narrative_bot_job?) do
    SiteSetting.discourse_narrative_bot_enabled && self.human? && !self.anonymous? &&
      !self.staged &&
      !SiteSetting
        .discourse_narrative_bot_ignored_usernames
        .split("|".freeze)
        .include?(self.username)
  end

  self.on(:post_created) do |post, options|
    user = post.user

    if user&.enqueue_narrative_bot_job? && !options[:skip_bot]
      Jobs.enqueue(:bot_input, user_id: user.id, post_id: post.id, input: "reply")
    end
  end

  self.on(:post_edited) do |post|
    if post.user&.enqueue_narrative_bot_job?
      Jobs.enqueue(:bot_input, user_id: post.user.id, post_id: post.id, input: "edit")
    end
  end

  self.on(:post_destroyed) do |post, options, user|
    if user&.enqueue_narrative_bot_job? && !options[:skip_bot]
      Jobs.enqueue(
        :bot_input,
        user_id: user.id,
        post_id: post.id,
        topic_id: post.topic_id,
        input: "delete",
      )
    end
  end

  self.on(:post_recovered) do |post, _, user|
    if user&.enqueue_narrative_bot_job?
      Jobs.enqueue(:bot_input, user_id: user.id, post_id: post.id, input: "recover")
    end
  end

  self.add_model_callback(PostAction, :after_commit, on: :create) do
    if self.post && self.user.enqueue_narrative_bot_job?
      input =
        case self.post_action_type_id
        when *PostActionType.flag_types.values
          self.post_action_type_id == PostActionType.types[:inappropriate] ? "flag" : "reply"
        when PostActionType.types[:like]
          "like"
        end

      Jobs.enqueue(:bot_input, user_id: self.user.id, post_id: self.post.id, input: input) if input
    end
  end

  self.add_model_callback(Bookmark, :after_commit, on: :create) do
    if self.user.enqueue_narrative_bot_job?
      if self.bookmarkable_type == "Post" || self.bookmarkable_type == "Topic"
        is_topic = self.bookmarkable_type == "Topic"
        first_post_id =
          Post.where(topic_id: self.bookmarkable_id, post_number: 1).pick(:id) if is_topic

        Jobs.enqueue(
          :bot_input,
          user_id: self.user_id,
          post_id: is_topic ? first_post_id : self.bookmarkable_id,
          input: "bookmark",
        )
      end
    end
  end

  self.on(:topic_notification_level_changed) do |_, user_id, topic_id|
    user = User.find_by(id: user_id)

    if user && user.enqueue_narrative_bot_job?
      Jobs.enqueue(
        :bot_input,
        user_id: user_id,
        topic_id: topic_id,
        input: "topic_notification_level_changed",
      )
    end
  end

  UserAvatar.register_custom_user_gravatar_email_hash(
    DiscourseNarrativeBot::BOT_USER_ID,
    "discobot@discourse.org",
  )

  self.on(:system_message_sent) do |args|
    next if !SiteSetting.discourse_narrative_bot_enabled
    next if args[:message_type] != "tl2_promotion_message"

    recipient = args[:recipient]
    next if recipient.nil?

    I18n.with_locale(recipient.effective_locale) do
      raw =
        I18n.t(
          "discourse_narrative_bot.tl2_promotion_message.text_body_template",
          discobot_username: ::DiscourseNarrativeBot::Base.new.discobot_username,
          reset_trigger:
            "#{::DiscourseNarrativeBot::TrackSelector.reset_trigger} #{::DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger}",
        )

      PostCreator.create!(
        ::DiscourseNarrativeBot::Base.new.discobot_user,
        title: I18n.t("discourse_narrative_bot.tl2_promotion_message.subject_template"),
        raw: raw,
        skip_validations: true,
        archetype: Archetype.private_message,
        target_usernames: recipient.username,
      )
    end
  end

  self.on(:site_setting_changed) do |name, old_value, new_value|
    next if name.to_s != "default_locale"
    next if !SiteSetting.discourse_narrative_bot_enabled

    profile = UserProfile.find_by(user_id: DiscourseNarrativeBot::BOT_USER_ID)

    next if profile.blank?

    new_bio = I18n.with_locale(new_value) { I18n.t("discourse_narrative_bot.bio") }
    profile.update!(bio_raw: new_bio)
  end

  PostGuardian.prepend(DiscourseNarrativeBot::PostGuardianExtension)
end
