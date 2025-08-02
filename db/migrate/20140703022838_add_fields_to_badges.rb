# frozen_string_literal: true

class AddFieldsToBadges < ActiveRecord::Migration[4.2]
  def change
    add_column :badges, :listable, :boolean, default: true
    add_column :badges, :target_posts, :boolean, default: false
    add_column :badges, :query, :text
  end
end
