# frozen_string_literal: true
class RebakeUserOnebox < ActiveRecord::Migration[7.1]
  def up
    # Rebake user onebox posts for fontawesome6 upgrade
    execute <<~SQL
      UPDATE posts SET baked_version = 0
      WHERE cooked LIKE '%d-icon-map-marker-alt%'
    SQL
  end

  def down
    # do nothing
  end
end
