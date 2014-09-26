class AddEditableToUserFields < ActiveRecord::Migration
  def change
    add_column :user_fields, :editable, :boolean, default: false, null: false
  end
end
