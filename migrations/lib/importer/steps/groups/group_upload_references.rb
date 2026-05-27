# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class GroupUploadReferences < Step
        depends_on :groups

        def execute
          super

          DB.exec(<<~SQL)
            INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
            SELECT flair_upload_id, 'Group', id, created_at, updated_at
            FROM groups
            WHERE flair_upload_id IS NOT NULL
            ON CONFLICT DO NOTHING
          SQL
        end
      end
    end
  end
end
