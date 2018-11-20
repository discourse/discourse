class CreatePostRevisions < ActiveRecord::Migration[4.2]
  def up
    create_table :post_revisions do |t|
      t.belongs_to :user
      t.belongs_to :post
      t.text :modifications
      t.integer :number
      t.timestamps null: false
    end

    execute "INSERT INTO post_revisions (user_id, post_id, modifications, number, created_at, updated_at)
             SELECT user_id, versioned_id, modifications, number, created_at, updated_at
             FROM   versions
             WHERE  versioned_type = 'Post'"

    change_table :post_revisions do |t|
      t.index :post_id
      t.index [:post_id, :number]
    end
  end

  def down
    drop_table :post_revisions
  end
end
