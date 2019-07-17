# frozen_string_literal: true

class MigrateGroupListSiteSettings < ActiveRecord::Migration[5.2]
  def up
    migrate_value(:name, :id)
  end

  def down
    migrate_value(:id, :name)
  end

  def migrate_value(from, to)
    cast_type = from == :id ? '::int[]' : ''
    DB.exec <<~SQL
      UPDATE site_settings
      SET value = COALESCE(array_to_string(
        (
          SELECT array_agg(groups.#{to})
          FROM groups
          WHERE groups.#{from} = ANY (string_to_array(site_settings.value, '|', '')#{cast_type})
        ),
        '|', ''
      ), site_settings.value)
      WHERE data_type = #{SiteSettings::TypeSupervisor.types[:group_list]}
    SQL
  end
end
