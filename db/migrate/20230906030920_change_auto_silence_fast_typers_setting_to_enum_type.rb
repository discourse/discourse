# frozen_string_literal: true

class ChangeAutoSilenceFastTypersSettingToEnumType < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE
        "site_settings"
      SET
        "data_type" = 7
      WHERE
        "name" = 'auto_silence_fast_typers_max_trust_level' AND
        "data_type" = 3
    SQL
  end

  def down
    execute <<~SQL
      UPDATE
        "site_settings"
      SET
        "data_type" = 3
      WHERE
        "name" = 'auto_silence_fast_typers_max_trust_level' AND
        "data_type" = 7
    SQL
  end
end
