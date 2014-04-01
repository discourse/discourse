module Jobs

  class UpdateUserInfo < Jobs::Base

    def execute(args)
      user = User.where(id: args[:user_id]).first
      user.update_last_seen!
      user.update_ip_address!(args[:ip_address])
    end
  end

end
