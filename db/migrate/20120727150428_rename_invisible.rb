class RenameInvisible < ActiveRecord::Migration
  def change

    add_column :forum_threads, :visible, :boolean, default: true, null: false
    execute "UPDATE forum_threads SET visible = CASE WHEN invisible THEN false ELSE true END"
    remove_column :forum_threads, :invisible

  end
end
