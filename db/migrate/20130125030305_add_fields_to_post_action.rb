# frozen_string_literal: true

class AddFieldsToPostAction < ActiveRecord::Migration[4.2]
  def change
    add_column :post_actions, :deleted_by, :integer
    add_column :post_actions, :message, :text
  end
end
