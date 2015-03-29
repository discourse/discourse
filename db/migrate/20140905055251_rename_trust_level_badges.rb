class RenameTrustLevelBadges < ActiveRecord::Migration

  def rename(id, old, new)
    execute "UPDATE badges SET name = '#{new}' WHERE name = '#{old}' AND id = #{id}"
  rescue
    puts "#{new} badge is already in use, skipping rename"
  end

  def up
    rename 2, 'Regular User', 'Member'
    rename 3, 'Leader', 'Regular'
    rename 4, 'Elder', 'Leader'
  end

  def down
    rename 2, 'Member', 'Regular User'
    rename 3, 'Regular', 'Leader'
    rename 4, 'Leader', 'Elder'
  end
end
