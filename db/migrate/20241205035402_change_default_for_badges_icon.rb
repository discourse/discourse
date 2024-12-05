# frozen_string_literal: true
class ChangeDefaultForBadgesIcon < ActiveRecord::Migration[7.2]
  def change
    change_column_default :badges, :icon, from: "fa-certificate", to: "certificate"

    up_only { execute <<~SQL }
        UPDATE badges
        SET icon = 'certificate'
        WHERE icon LIKE 'fa-certificate';
      SQL
  end
end
