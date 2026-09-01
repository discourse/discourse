# frozen_string_literal: true

module Migration
  module Helpers
    class << self
      def site_created_at
        Discourse.site_creation_date
      end

      def existing_site?
        site_created_at < 1.hour.ago
      end

      def new_site?
        !existing_site?
      end
    end
  end
end
