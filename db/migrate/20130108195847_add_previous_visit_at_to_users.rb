class AddPreviousVisitAtToUsers < ActiveRecord::Migration
  def change
    add_column :users, :previous_visit_at, :timestamp
  end
end
