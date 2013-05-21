class FixTopicAllowedGroups < ActiveRecord::Migration
  def change
    # big oops
    remove_column :topic_allowed_groups, :integer
  end
end
