# frozen_string_literal: true

class CreateVoiceCredits < ActiveRecord::Migration[7.0]
  def change
    create_table :voice_credits do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.integer :category_id, null: false
      t.integer :credits_allocated, null: false, default: 0

      t.timestamps
    end

    add_index :voice_credits, %i[user_id topic_id category_id], unique: true
  end
end
