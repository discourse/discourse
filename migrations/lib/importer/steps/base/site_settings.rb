# frozen_string_literal: true

module Migrations::Importer::Steps::Base
  class SiteSettings < ::Migrations::Importer::CopyStep
    requires_mapping :existing_site_settings, "SELECT name, value, updated_at FROM site_settings"

    total_rows_query "SELECT COUNT(*) FROM site_settings WHERE"

    protected

    def copy_data
    end
  end
end
