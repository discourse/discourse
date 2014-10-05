class IncrementReservedTrustLevelBadgeIds < ActiveRecord::Migration
  def up
    execute "ALTER SEQUENCE badges_id_seq START WITH 100"

    max_badge_id = Badge.order('id DESC').limit(1).first.try(:id)
    Badge.where('id > 0 AND id <= 100').find_each do |badge|
      new_id = badge.id + max_badge_id + 100
      UserBadge.where(badge_id: badge.id).update_all badge_id: new_id
      badge.update_column :id, new_id
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
