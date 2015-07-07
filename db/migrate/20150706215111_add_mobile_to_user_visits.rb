class AddMobileToUserVisits < ActiveRecord::Migration
  def change
    add_column :user_visits, :mobile, :boolean, default: false
  end
end
