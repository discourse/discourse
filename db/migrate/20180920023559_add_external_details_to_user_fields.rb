class AddExternalDetailsToUserFields < ActiveRecord::Migration[5.2]
  def change
    add_column :user_fields, :external_name, :string
    add_column :user_fields, :external_type, :string
  end
end
