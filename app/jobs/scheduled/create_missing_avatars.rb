module Jobs
  class CreateMissingAvatars < Jobs::Scheduled
    every 1.hour
    def execute(args)
      User.where(uploaded_avatar_id: nil).find_each do |u|
        u.refresh_avatar
        u.save
      end

      UserAvatar.where(system_upload_id: nil).find_each do |a|
        a.update_system_avatar!
      end
    end
  end
end
