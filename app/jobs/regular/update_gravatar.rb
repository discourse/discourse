# frozen_string_literal: true

module Jobs
  class UpdateGravatar < ::Jobs::Base
    sidekiq_options queue: "low"

    def execute(args)
      avatar = UserAvatar.find_by(id: args[:avatar_id], user_id: args[:user_id])
      return if avatar&.user&.primary_email.blank?

      avatar.update_gravatar!(selection: :if_missing)
    end
  end
end
