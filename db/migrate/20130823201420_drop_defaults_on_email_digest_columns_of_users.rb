class DropDefaultsOnEmailDigestColumnsOfUsers < ActiveRecord::Migration
  def up
    change_column_default :users, :email_digests,     nil
    change_column         :users, :digest_after_days, :integer, default: nil, null: true
  end

  def down
    change_column_default :users, :email_digests,     true
    change_column_default :users, :digest_after_days, 7
    change_column         :users, :digest_after_days, :integer, default: 7, null: false
  end
end
