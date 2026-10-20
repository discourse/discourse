# frozen_string_literal: true

class RenameVoicePatronBadge < ActiveRecord::Migration[8.1]
  def up
    badge = DB.query(<<~SQL).first
        SELECT id, created_at, badge_grouping_id
        FROM badges
        WHERE name = 'Patron' AND query LIKE '%voice_sessions%'
      SQL

    return if badge.nil?

    # The rest of the voice badges were seeded in one run, so a Patron badge
    # older than all of them belonged to the site before voice claimed the name.
    seeded_at =
      DB.query_single(
        "SELECT MIN(created_at) FROM badges WHERE badge_grouping_id = :grouping_id AND id <> :id",
        grouping_id: badge.badge_grouping_id,
        id: badge.id,
      ).first

    if seeded_at.present? && badge.created_at < seeded_at - 1.hour
      # Not ours to rename. Hand it back so the site can repair it by hand; the
      # query is left in place so a plugin that owns the name can still find it.
      DB.exec("UPDATE badges SET system = false WHERE id = :id", id: badge.id)
      return
    end

    return if DB.query_single("SELECT 1 FROM badges WHERE name = 'Frequenter'").present?

    DB.exec("UPDATE badges SET name = 'Frequenter' WHERE id = :id", id: badge.id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
