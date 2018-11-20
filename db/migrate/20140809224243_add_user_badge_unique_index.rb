class AddUserBadgeUniqueIndex < ActiveRecord::Migration[4.2]
  def up
    # used to keep badges distinct
    add_column :user_badges, :seq, :integer, default: 0, null: false

    # invent artificial seq for badges
    execute "
      UPDATE user_badges ub1 SET seq = X.seq
      FROM (
        SELECT ub.id, rank() OVER (PARTITION BY user_id ORDER BY granted_at) seq
        FROM user_badges ub
        JOIN badges b ON b.id = ub.badge_id
        WHERE b.multiple_grant
      ) X
      WHERE ub1.id = X.id
    "

    # delete all single award dupes
    execute "
      DELETE FROM user_badges ub1
      WHERE ub1.id NOT IN (
        SELECT MIN(ub.id)
        FROM user_badges ub
        GROUP BY ub.user_id, ub.badge_id, ub.seq
      )
    "

    add_index :user_badges, [:badge_id, :user_id, :seq], unique: true, where: 'post_id IS NULL'
  end

  def down
    remove_column :user_badges, :seq, :integer
  end
end
