class AddAllowMembershipRequestsToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :allow_membership_requests, :boolean, default: false, null: false
  end
end
