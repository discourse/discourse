class FixTopicAllowedGroups < ActiveRecord::Migration[4.2]
  def change
    # big oops
    remove_column :topic_allowed_groups, :integer
  end
end
