# frozen_string_literal: true

class UpdateSequenceForGroups < ActiveRecord::Migration[4.2]
  def up
    # even if you alter a sequence you still need to set the seq
    execute <<SQL
    SELECT setval('groups_id_seq', 40)
SQL
  end

  def down
  end
end
