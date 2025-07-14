# frozen_string_literal: true

class RenameSiteSettingAssignEmailer < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE site_settings
             SET name = 'assign_mailer', value = '#{AssignMailer.levels[:always]}', data_type = #{SiteSettings::TypeSupervisor.types[:enum]}
             WHERE name = 'assign_mailer_enabled' AND value = 't' AND data_type = #{SiteSettings::TypeSupervisor.types[:enum]}"

    execute "UPDATE site_settings
             SET name = 'assign_mailer', value = '#{AssignMailer.levels[:never]}', data_type = #{SiteSettings::TypeSupervisor.types[:enum]}
             WHERE name = 'assign_mailer_enabled' AND value = 'f' AND data_type = #{SiteSettings::TypeSupervisor.types[:enum]}"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
