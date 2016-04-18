class AddBounceKeyToEmailLog < ActiveRecord::Migration
  def change
    add_column :email_logs, :bounce_key, :string
  end
end
