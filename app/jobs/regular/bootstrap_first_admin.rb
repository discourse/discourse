# frozen_string_literal: true

module Jobs
  class BootstrapFirstAdmin < ::Jobs::Base
    sidekiq_options queue: "critical"

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) if !args[:user_id].present?

      user = User.find_by(id: args[:user_id])
      return if !user.is_singular_admin?

      user.grant_moderation!
      StaffActionLogger.new(Discourse.system_user).log_grant_moderation(user)
    end
  end
end
