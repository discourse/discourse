class AddPreviousVisitAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :previous_visit_at, :timestamp
  end
end
