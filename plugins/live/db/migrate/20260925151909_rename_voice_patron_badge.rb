# frozen_string_literal: true

class RenameVoicePatronBadge < ActiveRecord::Migration[8.1]
  # The plugin's grouping is renamed later, so either name may be in place here.
  PLUGIN_GROUPINGS = %w[Voice Live]

  def up
    badge = DB.query(<<~SQL).first
      SELECT id, created_at, badge_grouping_id
      FROM badges
      WHERE name = 'Patron' AND (query LIKE '%voice_sessions%' OR query LIKE '%live_sessions%')
    SQL

    return if badge.nil?

    # Patreon seeds its patrons group alongside its Patron badge, so on a site
    # with that group this record is Patreon's whatever its age or grouping.
    if DB.query_single("SELECT 1 FROM groups WHERE name = 'patrons'").present?
      return hand_back(badge)
    end

    # The seed only moves a badge out of a core grouping, so one left in any
    # other grouping was placed there by the site.
    in_plugin_grouping =
      DB.query_single(
        "SELECT 1 FROM badge_groupings WHERE id = :id AND name IN (:names)",
        id: badge.badge_grouping_id,
        names: PLUGIN_GROUPINGS,
      ).present?
    return hand_back(badge) if !in_plugin_grouping

    # The plugin's other badges were seeded in one run, so a Patron badge older
    # than all of them belonged to the site before the plugin claimed the name.
    seeded_at =
      DB.query_single(
        "SELECT MIN(created_at) FROM badges WHERE badge_grouping_id = :grouping_id AND id <> :id",
        grouping_id: badge.badge_grouping_id,
        id: badge.id,
      ).first
    return hand_back(badge) if seeded_at.present? && badge.created_at < seeded_at - 1.hour

    return if DB.query_single("SELECT 1 FROM badges WHERE name = 'Frequenter'").present?

    DB.exec("UPDATE badges SET name = 'Frequenter' WHERE id = :id", id: badge.id)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Not ours to rename. The query is left in place so a plugin that owns the
  # name can still find it; otherwise the site repairs it by hand.
  def hand_back(badge)
    DB.exec("UPDATE badges SET system = false WHERE id = :id", id: badge.id)
  end
end
