# frozen_string_literal: true

module Jobs
  class EnableBootstrapMode < ::Jobs::Base
    sidekiq_options queue: 'critical'

    def execute(args)
      raise Discourse::InvalidParameters.new(:user_id) unless args[:user_id].present?
      return if SiteSetting.bootstrap_mode_enabled

      user = User.find_by(id: args[:user_id])
      return unless user.is_singular_admin?

      # let's enable bootstrap mode settings
      if SiteSetting.default_trust_level == TrustLevel[0]
        SiteSetting.set_and_log('default_trust_level', TrustLevel[1])
      end

      if SiteSetting.default_email_digest_frequency == 10080
        SiteSetting.set_and_log('default_email_digest_frequency', 1440)
      end

      SiteSetting.set_and_log('bootstrap_mode_enabled', true)
    end
  end
end
