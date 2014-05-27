module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
      UserAvatar.where(system_upload_id: nil).find_each do |a|
        a.update_system_avatar!
      end

      # backfill in batches 1000 an hour
      User.where(uploaded_avatar_id: nil)
          .order("last_posted_at desc")
          .limit(1000).find_each do |u|
        u.refresh_avatar
        u.save
      end
    end
  end
end
