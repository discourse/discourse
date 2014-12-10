module Jobs
  class RefreshGravatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
      return unless SiteSetting.enable_gravatar && SiteSetting.automatically_refresh_gravatars
      # backfill in batches 5000 an hour
      UserAvatar
          .where("last_gravatar_download_attempt = ? OR last_gravatar_download_attempt < ?",
              nil, 3.days.ago)
          .includes(:user)
          .order("users.last_posted_at desc")
          .limit(5000).each do |u|
        u.user.refresh_gravatar
        u.user.save
      end
    end
  end
end
