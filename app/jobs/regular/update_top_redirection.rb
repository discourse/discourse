module Jobs

  class UpdateTopRedirection < Jobs::Base

    def execute(args)
      user = User.where(id: args[:user_id]).first
      user.update_column(:last_redirected_to_top_at, args[:redirected_at])
    end
  end

end
