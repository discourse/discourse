# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas
    class User
      BASE_FIELDS = {
        user_id: :integer,
        username: :string,
        name: :string,
        trust_level: :integer,
        admin: :boolean,
        moderator: :boolean,
      }.freeze

      def self.fields
        BASE_FIELDS
      end

      def self.resolve(user)
        return {} if user.nil?

        {
          user_id: user.id,
          username: user.username,
          name: user.name,
          trust_level: user.trust_level,
          admin: user.admin?,
          moderator: user.moderator?,
        }
      end
    end
  end
end
