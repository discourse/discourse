# frozen_string_literal: true

class CreateNotificationType < ActiveRecord::Migration[5.2]
  def change
    create_table :notification_types do |t|
      t.string :name, index: { unique: true }
    end
  end
end
