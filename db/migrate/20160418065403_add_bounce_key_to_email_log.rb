class AddBounceKeyToEmailLog < ActiveRecord::Migration[4.2]
  def change
    add_column :email_logs, :bounce_key, :string
  end
end
