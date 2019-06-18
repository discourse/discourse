# frozen_string_literal: true

class AddEnableDeferToUserOptions < ActiveRecord::Migration[5.2]
  def change
    add_column :user_options, :enable_defer, :boolean, default: false, null: false
  end
end
