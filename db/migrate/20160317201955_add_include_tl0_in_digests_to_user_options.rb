class AddIncludeTl0InDigestsToUserOptions < ActiveRecord::Migration
  def change
    add_column :user_options, :include_tl0_in_digests, :boolean, default: false
  end
end
