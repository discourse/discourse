# frozen_string_literal: true

class MigrateSelectableAvatarsEnabled < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 't' THEN 'everyone'
          ELSE 'disabled'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:enum]},
        name = 'restrict_selectable_avatars_for'
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatar_restriction'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 'everyone' THEN 't'
          WHEN t.value = 'non_staff' THEN 't'
          WHEN t.value = 'under_tl1' THEN 't'
          WHEN t.value = 'under_tl2' THEN 't'
          WHEN t.value = 'under_tl3' THEN 't'
          WHEN t.value = 'under_tl3' THEN 't'
          WHEN t.value = 'under_tl4' THEN 't'
          ELSE 'f'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:bool]},
        name = 'selectable_avatars_enabled'
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatar_restriction'
    SQL
  end
end
