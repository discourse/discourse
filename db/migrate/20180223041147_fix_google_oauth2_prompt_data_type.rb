# frozen_string_literal: true

class FixGoogleOauth2PromptDataType < ActiveRecord::Migration[5.1]
  def up
    sql = <<~SQL
    UPDATE site_settings
    SET data_type=#{SiteSettings::TypeSupervisor.types[:list]}
    WHERE data_type=#{SiteSettings::TypeSupervisor.types[:enum]}
    AND name='google_oauth2_prompt'
    SQL

    execute sql
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
