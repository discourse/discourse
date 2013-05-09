class UpdateSequenceForGroups < ActiveRecord::Migration
  def up
    # even if you alter a sequence you still need to set the seq
    execute <<SQL
    SELECT setval('groups_id_seq', 40)
SQL
  end

  def down
  end
end
