# frozen_string_literal: true

class AddCustomTypeToUserHistories < ActiveRecord::Migration[4.2]
  def change
    add_column :user_histories, :custom_type, :string
  end
end
