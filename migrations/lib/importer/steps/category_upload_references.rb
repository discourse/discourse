# frozen_string_literal: true

module Migrations::Importer::Steps
  class CategoryUploadReferences < ::Migrations::Importer::Step
    depends_on :categories

    def execute
      super

      DB.exec(<<~SQL)
        INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
        SELECT upload_id, 'Category', target_id, created_at, updated_at
        FROM (
               SELECT uploaded_logo_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_logo_id IS NOT NULL
                UNION ALL
               SELECT uploaded_logo_dark_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_logo_dark_id IS NOT NULL
                UNION ALL
               SELECT uploaded_background_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_background_id IS NOT NULL
                UNION ALL
               SELECT uploaded_background_dark_id AS upload_id, id AS target_id, created_at, updated_at
                 FROM categories
                WHERE uploaded_background_dark_id IS NOT NULL
             ) AS category_upload_refs
          ON CONFLICT DO NOTHING
      SQL
    end
  end
end
