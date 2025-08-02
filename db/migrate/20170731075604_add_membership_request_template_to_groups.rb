# frozen_string_literal: true

class AddMembershipRequestTemplateToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :membership_request_template, :text
  end
end
