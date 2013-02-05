class AddLastEditorIdToPosts < ActiveRecord::Migration
  def change
    add_column :posts, :last_editor_id, :integer
  end
end
