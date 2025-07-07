# frozen_string_literal: true

module Migrations::Importer::Steps
  class BadgeUploadReferences < ::Migrations::Importer::Step
    depends_on :badges

    def execute
      super

      DB.exec(<<~SQL)
        INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
        SELECT image_upload_id, 'Badge', id, created_at, updated_at
        FROM badges b
        WHERE image_upload_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
    end
  end
end
