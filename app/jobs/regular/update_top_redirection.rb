module Jobs

  class UpdateTopRedirection < Jobs::Base

    def execute(args)
      return if args[:user_id].blank? || args[:redirected_at].blank?

      UserOption
        .where(user_id: args[:user_id])
        .limit(1)
        .update_all(last_redirected_to_top_at: args[:redirected_at])
    end
  end

end
