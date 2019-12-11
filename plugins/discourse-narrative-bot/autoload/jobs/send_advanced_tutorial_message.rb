# frozen_string_literal: true

module Jobs
  class SendAdvancedTutorialMessage < ::Jobs::Base
    def execute(args)
      user = User.find_by(id: args[:user_id])
      return if user.nil?

      PostCreator.create!(
        Discourse.system_user,
        title: I18n.t("discourse_narrative_bot.tl2_promotion_message.subject_template"),
        raw: I18n.t("discourse_narrative_bot.tl2_promotion_message.text_body_template"),
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true
      )
    end
  end
end
