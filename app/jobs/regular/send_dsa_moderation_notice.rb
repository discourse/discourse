# frozen_string_literal: true

module Jobs
  class SendDsaModerationNotice < SendSystemMessage
    private

    def message_options(args:, user:)
      ::Dsa::ModerationNotice.message_options(
        community_rule: args.fetch(:community_rule),
        message_type: args.fetch(:message_type),
        message_options: super,
        locale: user.effective_locale,
      )
    end
  end
end
