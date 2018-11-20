class AddAutomaticMembershipToGroup < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :automatic_membership_email_domains, :text
    add_column :groups, :automatic_membership_retroactive, :boolean, default: false
  end
end
