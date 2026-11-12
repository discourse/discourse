# frozen_string_literal: true

class RebakeGraphvizPosts < ActiveRecord::Migration[7.2]
  def up
    # Rebake posts with graphviz graphs to apply updated link sanitization
    execute <<~SQL
      UPDATE posts
      SET baked_version = 0
      WHERE raw LIKE '%[graphviz]%'
        OR cooked LIKE '%class="graphviz%'
    SQL
  end

  def down
    # Do nothing
  end
end
