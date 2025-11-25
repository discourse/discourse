# frozen_string_literal: true

class UpdateSummarizerPersonaToTrustLevel1 < ActiveRecord::Migration[8.0]
  def up
    # Update Summarizer persona (ID: -11) from TL3 to TL1 if it has the old default groups
    # Old default: [3, 13] (staff + TL3)
    # New default: [3, 11] (staff + TL1)

    staff_group_id = 3 # Group::AUTO_GROUPS[:staff]
    old_tl_group_id = 13 # Group::AUTO_GROUPS[:trust_level_3]
    new_tl_group_id = 11 # Group::AUTO_GROUPS[:trust_level_1]

    DB.exec(
      <<~SQL,
      UPDATE ai_personas
      SET allowed_group_ids = ARRAY[:staff, :new_tl]
      WHERE id = :id
        AND (
          allowed_group_ids = ARRAY[:staff, :old_tl]
          OR allowed_group_ids = ARRAY[:old_tl, :staff]
        )
    SQL
      id: -11,
      staff: staff_group_id,
      old_tl: old_tl_group_id,
      new_tl: new_tl_group_id,
    )
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
