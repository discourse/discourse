# frozen_string_literal: true

class RenumberGroupVisibilityLevels < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE groups SET visibility_level = 4 WHERE visibility_level = 3"
    execute "UPDATE groups SET visibility_level = 3 WHERE visibility_level = 2"
    execute "UPDATE groups SET visibility_level = 2 WHERE visibility_level = 1"
  end

  def down
    execute "UPDATE groups SET visibility_level = 0 WHERE visibility_level = 1"
    execute "UPDATE groups SET visibility_level = 1 WHERE visibility_level = 2"
    execute "UPDATE groups SET visibility_level = 2 WHERE visibility_level = 3"
    execute "UPDATE groups SET visibility_level = 3 WHERE visibility_level = 4"
  end
end
