class AddIndexUserIdOnUserSecondFactors < ActiveRecord::Migration[5.2]
  def change
    add_index :user_second_factors, :user_id
  end
end
