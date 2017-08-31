class CreatePostOneboxRenders < ActiveRecord::Migration[4.2]
  def change
    create_table :post_onebox_renders, id: false do |t|
      t.references :post, null: false
      t.references :onebox_render, null: false
      t.timestamps null: false
    end
    add_index :post_onebox_renders, [:post_id, :onebox_render_id], unique: true
  end
end
