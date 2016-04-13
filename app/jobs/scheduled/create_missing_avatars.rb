module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour

    def execute(args)
      # backfill in batches of 5000 an hour
      UserAvatar.includes(:user)
                .where(last_gravatar_download_attempt: nil)
                .order("users.last_posted_at DESC")
                .find_in_batches(batch_size: 5000) do |user_avatars|
        user_avatars.each do |user_avatar|
          user_avatar.user.refresh_avatar
        end
      end
    end
  end
end
