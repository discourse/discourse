# frozen_string_literal: true

class AddTriggerToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :trigger, :integer
  end
end
