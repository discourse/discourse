class RemoveUserFirsts < ActiveRecord::Migration
  def up
    drop_table(:user_firsts) if table_exists?(:user_firsts)
  rescue
    # continues with other migrations if we can't delete that table
    nil
  end
end
