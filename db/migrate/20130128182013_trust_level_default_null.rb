class TrustLevelDefaultNull < ActiveRecord::Migration
  def up
    change_column_default :users, :trust_level, nil
  end

  def down
    change_column_default :users, :trust_level, 0
  end
end
