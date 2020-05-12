# frozen_string_literal: true

class AddMoreFlairColumnsToGroup < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :flair_icon, :string
    add_reference :groups, :flair_image, foreign_key: { to_table: :uploads }
  end
end
