# frozen_string_literal: true

module DiscourseWorkflows
  module Schemas
    class Group
      BASE_FIELDS = {
        id: :integer,
        name: :string,
        full_name: :string,
        user_count: :integer,
        automatic: :boolean,
        visibility_level: :integer,
        mentionable_level: :integer,
        messageable_level: :integer,
        bio_raw: :string,
        created_at: :string,
      }.freeze

      def self.fields
        BASE_FIELDS
      end

      def self.resolve(group)
        {
          id: group.id,
          name: group.name,
          full_name: group.full_name,
          user_count: group.user_count,
          automatic: group.automatic,
          visibility_level: group.visibility_level,
          mentionable_level: group.mentionable_level,
          messageable_level: group.messageable_level,
          bio_raw: group.bio_raw,
          created_at: group.created_at&.iso8601,
        }
      end
    end
  end
end
