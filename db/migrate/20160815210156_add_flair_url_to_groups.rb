# frozen_string_literal: true

class AddFlairUrlToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :flair_url,      :string
    add_column :groups, :flair_bg_color, :string
  end
end
