module Jobs

  class UpdateTopRedirection < Jobs::Base

    def execute(args)
      if user = User.find_by(id: args[:user_id])
        user.update_column(:last_redirected_to_top_at, args[:redirected_at])
      end
    end
  end

end
