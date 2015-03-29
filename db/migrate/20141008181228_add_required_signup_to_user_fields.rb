class AddRequiredSignupToUserFields < ActiveRecord::Migration
  def change
    add_column :user_fields, :required, :boolean, default: true, null: false
  end
end
