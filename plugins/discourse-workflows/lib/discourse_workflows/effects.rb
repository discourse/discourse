# frozen_string_literal: true

module DiscourseWorkflows
  module Effects
    TYPES = {
      personal_message: %i[recipient title body],
      post_created: %i[topic_id raw],
      post_edited: %i[post_id raw],
      post_deleted: %i[post_id],
      post_recovered: %i[post_id],
      topic_created: %i[title category_id raw],
      topic_closed: %i[topic_id],
      topic_archived: %i[topic_id],
      topic_bumped: %i[topic_id],
      topic_tagged: %i[topic_id tags],
      topic_category_changed: %i[topic_id category_id],
      topic_pinned: %i[topic_id],
      topic_unpinned: %i[topic_id],
      badge_granted: %i[username badge_id],
      badge_revoked: %i[username badge_id],
      group_member_added: %i[username group_id],
      group_member_removed: %i[username group_id],
      user_updated: %i[username],
      http_request: %i[method url body],
      delay: %i[seconds],
    }.freeze

    def self.type?(type)
      TYPES.key?(type.to_sym)
    end

    def self.fields_for(type)
      TYPES.fetch(type.to_sym)
    end

    def self.serialized
      TYPES.map { |type, fields| { type: type.to_s, fields: fields.map(&:to_s) } }
    end
  end
end
