# frozen_string_literal: true

class MigrateSelectableAvatarsEnabled < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 't' THEN 'restrict_all'
          ELSE 'none'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:enum]}
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatars_enabled'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE site_settings AS s
        SET value =
          CASE WHEN t.value = 'restrict_all' THEN 't'
          WHEN t.value = 'restrict_nonstaff' THEN 't'
          ELSE 'f'
          END,
        data_type = #{SiteSettings::TypeSupervisor.types[:bool]}
        FROM site_settings t
        WHERE s.id = t.id AND s.name = 'selectable_avatars_enabled'
    SQL
  end
end
