module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
      UserAvatar
        .where("system_upload_id IS NULL OR system_avatar_version != ?", UserAvatar::SYSTEM_AVATAR_VERSION)
        .find_each do |a|
          if a.user
            a.update_system_avatar!
          else
            Rails.logger.warn("Detected stray avatar for avatar_user_id #{a.id}")
          end
      end

      # backfill in batches 5000 an hour
      UserAvatar.where(last_gravatar_download_attempt: nil).includes(:user)
          .order("users.last_posted_at desc")
          .limit(5000).each do |u|
        u.user.refresh_avatar
        u.user.save
      end
    end
  end
end
