# frozen_string_literal: true

module Migrations::Importer::Steps
  class Users < ::Migrations::Importer::CopyStep
    private

    def max_progress
      @intermediate_db.count("SELECT COUNT(*) FROM users")
    end

    def sql_query
      <<~SQL
        SELECT *
        FROM users
        ORDER BY rowid
      SQL
    end

    def table_name
      :users
    end

    def column_names
      %i[
        id
        username
        username_lower
        name
        active
        trust_level
        admin
        moderator
        date_of_birth
        ip_address
        registration_ip_address
        primary_group_id
        suspended_at
        suspended_till
        last_seen_at
        last_emailed_at
        created_at
        updated_at
      ]
    end

    def mapping_type
      1
    end

    def transform_row(row)
      row[:original_id] = row[:id]
      row[:id] = (@last_id += 1)

      row[:username] = row[:username].unicode_normalize!
      row[:username_lower] = row[:username].downcase

      row[:created_at] ||= NOW
      row[:updated_at] = row[:created_at]
      row
    end
  end
end
