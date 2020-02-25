# frozen_string_literal: true

module Jobs
  class SendAdvancedTutorialMessage < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if user.nil?

      raw = I18n.t("discourse_narrative_bot.tl2_promotion_message.text_body_template",
                    discobot_username: ::DiscourseNarrativeBot::Base.new.discobot_user.username,
                    reset_trigger: "#{::DiscourseNarrativeBot::TrackSelector.reset_trigger} #{::DiscourseNarrativeBot::AdvancedUserNarrative.reset_trigger}")

      PostCreator.create!(
        Discourse.system_user,
        title: I18n.t("discourse_narrative_bot.tl2_promotion_message.subject_template"),
        raw: raw,
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true
      )
    end
  end
end
