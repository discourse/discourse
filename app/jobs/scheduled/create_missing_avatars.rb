module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
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
