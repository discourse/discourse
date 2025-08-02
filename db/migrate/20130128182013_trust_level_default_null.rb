# frozen_string_literal: true

class TrustLevelDefaultNull < ActiveRecord::Migration[4.2]
  def up
    change_column_default :users, :trust_level, nil
  end

  def down
    change_column_default :users, :trust_level, 0
  end
end
