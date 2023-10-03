# frozen_string_literal: true

module Migration
  module Helpers
    def self.site_created_at
      result = DB.query_single <<~SQL
        SELECT created_at
        FROM schema_migration_details
        ORDER BY created_at
        LIMIT 1
      SQL
      result.first
    end

    def self.existing_site?
      site_created_at < 1.hour.ago
    end

    def self.new_site?
      !old_site?
    end
  end
end
