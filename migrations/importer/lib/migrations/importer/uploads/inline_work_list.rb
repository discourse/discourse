# frozen_string_literal: true

module Migrations
  module Importer
    module Uploads
      # The `upload_sources` still waiting to be uploaded in inline mode: rows with
      # no `mapped.ids` entry yet, joined to the mapped importer user that should
      # own each upload (falling back to the system user). Kept apart from the step
      # so the query can be tested against a plain SQLite fixture without Rails.
      module InlineWorkList
        ROWS_SQL = <<~SQL
          SELECT us.*, COALESCE(mu.discourse_id, ?3) AS resolved_user_id
          FROM upload_sources us
               LEFT JOIN mapped.ids mu ON us.user_id = mu.original_id AND mu.type = ?2
               LEFT JOIN mapped.ids mup ON us.id = mup.original_id AND mup.type = ?1
          WHERE mup.original_id IS NULL
          ORDER BY us.id
        SQL

        # Pulls the whole pending set into memory (data blobs included) so the
        # pipeline's workers never read the IntermediateDB connection. Fine because
        # inline mode is meant for small migrations.
        def self.rows(intermediate_db, system_user_id:)
          rows = []
          intermediate_db.query(
            ROWS_SQL,
            MappingType::UPLOADS,
            MappingType::USERS,
            system_user_id,
          ) { |row| rows << row }
          rows
        end

        # Rows without a `url` or `data` blob are read from disk, and only those
        # need the configured `root_paths`.
        def self.needs_root_paths?(rows)
          rows.any? { |row| row[:url].blank? && row[:data].blank? }
        end
      end
    end
  end
end
