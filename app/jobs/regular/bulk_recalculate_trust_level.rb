# frozen_string_literal: true

module Jobs
  class BulkRecalculateTrustLevel < ::Jobs::Base
    def execute(args)
      user_ids = args[:user_ids]

      raise Discourse::InvalidParameters.new(:user_ids) if user_ids.blank?

      User
        .where(id: user_ids)
        .find_each { |user| Promotion.recalculate(user, use_previous_trust_level: true) }
    end
  end
end
