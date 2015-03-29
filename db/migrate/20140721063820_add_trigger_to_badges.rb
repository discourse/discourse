class AddTriggerToBadges < ActiveRecord::Migration
  def change
    add_column :badges, :trigger, :integer
  end
end
