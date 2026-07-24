# frozen_string_literal: true

module Migration
  module Helpers
    def self.site_created_at
      Discourse.site_creation_date
    end

    def self.existing_site?
      site_created_at < 1.hour.ago
    end

    def self.new_site?
      !existing_site?
    end
  end
end
