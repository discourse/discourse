# frozen_string_literal: true

class SetUseEmailForUsernameAndNameSuggestionsOnExistingSites < ActiveRecord::Migration[6.1]
  def up
    # make setting enabled for existing sites
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('use_email_for_username_and_name_suggestions', 5, 't', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
