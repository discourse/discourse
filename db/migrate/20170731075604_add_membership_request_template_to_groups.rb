class AddMembershipRequestTemplateToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :membership_request_template, :text
  end
end
