module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
      UserAvatar
        .where("system_upload_id IS NULL OR system_avatar_version != ?", UserAvatar::SYSTEM_AVATAR_VERSION)
        .find_each do |a|
        a.update_system_avatar!
      end

      # backfill in batches 5000 an hour
      User.where(uploaded_avatar_id: nil)
          .order("last_posted_at desc")
          .limit(5000).each do |u|
        u.refresh_avatar
        u.save
      end
    end
  end
end
