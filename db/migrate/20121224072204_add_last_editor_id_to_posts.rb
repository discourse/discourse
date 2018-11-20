class AddLastEditorIdToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :last_editor_id, :integer
  end
end
