# frozen_string_literal: true

module Jobs
  class ClearExpiredImpersonations < ::Jobs::Scheduled
    every 30.minutes

    def execute(args)
      UserAuthToken.where("impersonation_expires_at < NOW()").update_all(
        impersonated_user_id: nil,
        impersonation_expires_at: nil,
      )
    end
  end
end
