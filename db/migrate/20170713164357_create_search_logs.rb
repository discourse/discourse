class CreateSearchLogs < ActiveRecord::Migration[4.2]
  def change
    create_table :search_logs do |t|
      t.string :term, null: false
      t.integer :user_id, null: true
      t.inet    :ip_address, null: false
      t.integer :clicked_topic_id, null: true
      t.integer :search_type, null: false
      t.datetime :created_at, null: false
    end
  end
end
