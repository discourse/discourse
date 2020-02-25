# frozen_string_literal: true

module Jobs
  class SendDefaultWelcomeMessage < ::Jobs::Base
    def execute(args)
      if user = User.find_by(id: args[:user_id])
        type = user.invited_by ? 'welcome_invite' : 'welcome_user'
        params = SystemMessage.new(user).defaults

        title = I18n.t("system_messages.#{type}.subject_template", params)
        raw = I18n.t("system_messages.#{type}.text_body_template", params)
        discobot_user = ::DiscourseNarrativeBot::Base.new.discobot_user

        post = PostCreator.create!(
          discobot_user,
          title: title,
          raw: raw,
          archetype: Archetype.private_message,
          target_usernames: user.username,
          skip_validations: true
        )

        post.topic.update_status('closed', true, discobot_user)
      end
    end
  end
end
