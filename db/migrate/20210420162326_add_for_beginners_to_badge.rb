# frozen_string_literal: true

class AddForBeginnersToBadge < ActiveRecord::Migration[6.0]
  def change
    add_column :badges, :for_beginners, :boolean, null: false, default: false
  end
end
