# frozen_string_literal: true

class RemoveEventHostRegistrationFormSetting < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'allow_event_hosts_to_create_new_registration_forms'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
