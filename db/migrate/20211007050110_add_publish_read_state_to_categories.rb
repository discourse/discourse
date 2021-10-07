# frozen_string_literal: true

class AddPublishReadStateToCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :categories, :publish_read_state, :boolean, null: false, default: false
  end
end
