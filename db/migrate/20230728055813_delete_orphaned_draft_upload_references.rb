# frozen_string_literal: true

class DeleteOrphanedDraftUploadReferences < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE
      FROM
        "upload_references"
      WHERE
        "upload_references"."target_type" = 'Draft' AND
        "upload_references"."target_id" NOT IN (
          SELECT "drafts"."id" FROM "drafts"
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
