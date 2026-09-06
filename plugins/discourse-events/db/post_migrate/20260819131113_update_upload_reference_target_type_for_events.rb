# frozen_string_literal: true

class UpdateUploadReferenceTargetTypeForEvents < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE upload_references
      SET target_type = 'DiscourseEvents::Events::Event'
      WHERE target_type = 'DiscoursePostEvent::Event'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
