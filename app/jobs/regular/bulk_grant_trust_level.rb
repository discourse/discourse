# frozen_string_literal: true

module Jobs
  class BulkGrantTrustLevel < ::Jobs::Base
    def execute(args)
      user_ids = args[:user_ids]
      trust_level = args[:trust_level]
      recalculate = args[:recalculate]

      raise Discourse::InvalidParameters.new(:user_ids) if user_ids.blank?
      raise Discourse::InvalidParameters.new(:trust_level) if trust_level.blank? && !recalculate

      User
        .where(id: user_ids)
        .find_each do |user|
          if recalculate
            Promotion.recalculate(user, use_previous_trust_level: true)
          else
            TrustLevelGranter.grant(trust_level, user)
          end
        end
    end
  end
end
