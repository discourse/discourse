class AddDefaultwatchUser < ActiveRecord::Migration
  def change
  	add_column :users, :default_watch, :string, default: ""
  end

end
