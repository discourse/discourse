# frozen_string_literal: true

class AddMoreFlairColumnsToGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :flair_icon, :string
    add_column :groups, :flair_image_id, :integer
  end
end
