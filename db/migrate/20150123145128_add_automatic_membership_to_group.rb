class AddAutomaticMembershipToGroup < ActiveRecord::Migration
  def change
    add_column :groups, :automatic_membership_email_domains, :text
    add_column :groups, :automatic_membership_retroactive, :boolean, default: false
  end
end
