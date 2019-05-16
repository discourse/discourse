# frozen_string_literal: true

class AddEnabledToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :enabled, :boolean, default: true, null: false
  end
end
