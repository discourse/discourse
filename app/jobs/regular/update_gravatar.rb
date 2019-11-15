# frozen_string_literal: true

module Jobs
  class UpdateGravatar < ::Jobs::Base

    sidekiq_options queue: 'low'

    def execute(args)
      user = User.find_by(id: args[:user_id])
      avatar = UserAvatar.find_by(id: args[:avatar_id])

      if user && avatar && avatar.user&.id == user.id && user.email.present?
        avatar.update_gravatar!
        if !user.uploaded_avatar_id && avatar.gravatar_upload_id
          user.update_column(:uploaded_avatar_id, avatar.gravatar_upload_id)
        end
      end
    end
  end

end
