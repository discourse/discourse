# frozen_string_literal: true

module Jobs

  class BulkGrantTrustLevel < ::Jobs::Base

    def execute(args)
      trust_level = args[:trust_level]
      user_ids = args[:user_ids]

      raise Discourse::InvalidParameters.new(:trust_level) if trust_level.blank?
      raise Discourse::InvalidParameters.new(:user_ids) if user_ids.blank?

      User.where(id: user_ids).find_each do |user|
        TrustLevelGranter.grant(trust_level, user)
      end
    end
  end
end
