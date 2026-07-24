# frozen_string_literal: true

class FixupIdSequences < ActiveRecord::Migration[8.0]
  def up
    # 20130506020935_add_automatic_to_groups ALTERed start_value to 100, then
    # 20130509040248_update_sequence_for_groups setval'd last_value to 40.
    # So realistically, 41+ has been the starting point for all sites since then.
    # Updating the sequence "START WITH" to reflect reality
    execute "ALTER SEQUENCE groups_id_seq START WITH 40"
    execute <<~SQL
      SELECT setval(
        'groups_id_seq',
        GREATEST(40, last_value),
        CASE WHEN last_value > 40 THEN is_called ELSE false END
      ) FROM groups_id_seq
    SQL

    # 20140504174212_increment_reserved_trust_level_badge_ids set start_value
    # to 100 to reserve 1-99 for system badges, but that reservation is
    # actually enforced by Badge#ensure_not_system at the model layer.
    # Revert START WITH to 1 to reflect what the sequence is really doing.
    execute "ALTER SEQUENCE badges_id_seq START WITH 1"
    execute <<~SQL
      SELECT setval(
        'badges_id_seq',
        GREATEST(1, last_value),
        CASE WHEN last_value > 1 THEN is_called ELSE false END
      ) FROM badges_id_seq
    SQL

    # 20240423054323_create_flags setval'd last_value to 1001 to reserve
    # 1-1000 for system flags, but `setval` isn't captured in structure.sql.
    # Sites restored from a structure.sql dumped before 20260518054805 added
    # the matching `ALTER … START WITH 1001` would land at last_value=1
    # — bump them defensively.
    execute <<~SQL
      SELECT setval(
        'flags_id_seq',
        GREATEST(1001, last_value),
        CASE WHEN last_value > 1001 THEN is_called ELSE false END
      ) FROM flags_id_seq
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
