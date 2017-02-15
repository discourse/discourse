class AddAllowMembershipRequestsToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :allow_membership_requests, :boolean, default: false, null: false
  end
end
