# frozen_string_literal: true

class CreatePollsTables < ActiveRecord::Migration[5.2]
  def change
    create_table :polls do |t|
      t.references :post, index: true, foreign_key: true
      t.string :name, null: false, default: "poll"
      t.datetime :close_at
      t.integer :type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.integer :results, null: false, default: 0
      t.integer :visibility, null: false, default: 0
      t.integer :min
      t.integer :max
      t.integer :step
      t.integer :anonymous_voters
      t.timestamps
    end

    add_index :polls, [:post_id, :name], unique: true

    create_table :poll_options do |t|
      t.references :poll, index: true, foreign_key: true
      t.string :digest, null: false
      t.text :html, null: false
      t.integer :anonymous_votes
      t.timestamps
    end

    add_index :poll_options, [:poll_id, :digest], unique: true

    create_table :poll_votes, id: false do |t|
      t.references :poll, foreign_key: true
      t.references :poll_option, foreign_key: true
      t.references :user, foreign_key: true
      t.timestamps
    end

    add_index :poll_votes, [:poll_id, :poll_option_id, :user_id], unique: true
  end
end
