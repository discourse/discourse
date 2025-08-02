# frozen_string_literal: true

class DescriptionOptionalInBadgeGrouping < ActiveRecord::Migration[4.2]
  def change
    change_column :badge_groupings, :description, :text, null: true
  end
end
