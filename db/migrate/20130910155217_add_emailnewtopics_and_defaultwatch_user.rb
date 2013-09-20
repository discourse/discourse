class AddEmailnewtopicsAndDefaultwatchUser < ActiveRecord::Migration
  def change
  	add_column :users, :email_new_topics, :boolean, default: false
  	add_column :users, :default_watch, :string, default: ""
  end

end
