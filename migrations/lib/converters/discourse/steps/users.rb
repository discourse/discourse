# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Users < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM users
        WHERE id >= 0
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM users
        WHERE id >= 0
        ORDER BY id
      SQL
    end

    def process_item(item)
      IntermediateDB::User.create(
        original_id: item[:id],
        active: item[:active],
        admin: item[:admin],
        approved: item[:approved],
        approved_at: item[:approved_at],
        approved_by_id: item[:approved_by_id],
        created_at: item[:created_at],
        date_of_birth: item[:date_of_birth],
        first_seen_at: item[:first_seen_at],
        flair_group_id: item[:flair_group_id],
        group_locked_trust_level: item[:group_locked_trust_level],
        ip_address: item[:ip_address],
        last_seen_at: item[:last_seen_at],
        locale: item[:locale],
        manual_locked_trust_level: item[:manual_locked_trust_level],
        moderator: item[:moderator],
        name: item[:name],
        primary_group_id: item[:primary_group_id],
        registration_ip_address: item[:registration_ip_address],
        silenced_till: item[:silenced_till],
        staged: item[:staged],
        title: item[:title],
        trust_level: item[:trust_level],
        uploaded_avatar_id: item[:uploaded_avatar_id],
        username: item[:username],
        views: item[:views],
      )
    end
  end
end
