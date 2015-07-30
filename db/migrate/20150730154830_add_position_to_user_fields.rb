class AddPositionToUserFields < ActiveRecord::Migration
  def change
    add_column :user_fields, :position, :integer, default: 0
    execute "UPDATE user_fields SET position = (SELECT COUNT(*) from user_fields as uf2 where uf2.id < user_fields.id)"
  end
end
