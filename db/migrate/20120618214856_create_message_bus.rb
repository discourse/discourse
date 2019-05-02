# frozen_string_literal: true

class CreateMessageBus < ActiveRecord::Migration[4.2]
  def change
    create_table :message_bus do |t|
      t.string :name
      t.string :context
      t.text :data
      t.datetime :created_at
    end

    add_index :message_bus, [:created_at]
  end

end
