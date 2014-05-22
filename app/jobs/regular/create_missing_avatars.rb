module Jobs
  class CreateMissingAvatars < Jobs::Base
    def execute(args)
      User.find_each do |u|
        u.refresh_avatar
        u.save
      end
    end
  end
end
