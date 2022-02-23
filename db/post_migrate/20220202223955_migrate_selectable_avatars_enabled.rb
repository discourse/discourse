# frozen_string_literal: true

class MigrateSelectableAvatarsEnabled < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 't' THEN 'no_one'
          ELSE 'disabled'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:enum]},
        name = 'selectable_avatars_mode'
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatars_enabled'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 'everyone' THEN 't'
          WHEN t.value = 'no_one' THEN 't'
          WHEN t.value = 'staff' THEN 't'
          WHEN t.value = 'tl1' THEN 't'
          WHEN t.value = 'tl2' THEN 't'
          WHEN t.value = 'tl3' THEN 't'
          WHEN t.value = 'tl3' THEN 't'
          WHEN t.value = 'tl4' THEN 't'
          ELSE 'f'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:bool]},
        name = 'selectable_avatars_enabled'
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatars_mode'
    SQL
  end
end
