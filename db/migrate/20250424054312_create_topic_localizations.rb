# frozen_string_literal: true

class CreateTopicLocalizations < ActiveRecord::Migration[7.2]
  def change
    create_table :topic_localizations do |t|
      t.integer :topic_id, null: false
      t.string :locale, null: false, limit: 20
      t.string :title, null: false
      t.string :fancy_title, null: false
      t.integer :localizer_user_id, null: false
      t.timestamps
    end

    add_index :topic_localizations, :topic_id
    add_index :topic_localizations, %i[topic_id locale], unique: true
  end
end
