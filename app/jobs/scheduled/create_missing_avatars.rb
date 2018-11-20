module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour

    def execute(args)
      # backfill in batches of 5000 an hour
      UserAvatar.includes(:user)
        .joins(:user)
        .where(last_gravatar_download_attempt: nil)
        .order("users.last_posted_at DESC")
        .limit(5000)
        .each do |u|
        u.user.refresh_avatar
      end
    end
  end
end
