class CreateWatchedWords < ActiveRecord::Migration
  def change
    create_table :watched_words do |t|
      t.string  :word,   null: false
      t.integer :action, null: false
      t.timestamps null: false
    end

    add_index :watched_words, [:action, :word], unique: true
  end
end
