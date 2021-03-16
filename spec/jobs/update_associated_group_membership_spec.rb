# frozen_string_literal: true

require 'rails_helper'

describe Jobs::UpdateAssociatedGroupMemberships do

  it "updates associated group memberships" do
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)
    user3 = Fabricate(:user)

    UserAssociatedGroup.create!(provider_name: "google_oauth2", user_id: user1.id, group: "group1")
    UserAssociatedGroup.create!(provider_name: "google_oauth2", user_id: user2.id, group: "group2")
    UserAssociatedGroup.create!(provider_name: "github", user_id: user3.id, group: "group1")

    group1 = Fabricate(:group, associated_groups: "google_oauth2:group1")
    group2 = Fabricate(:group, associated_groups: "google_oauth2:group1|google_oauth2:group2")
    group3 = Fabricate(:group, associated_groups: "github:group1|google_oauth2:group2")

    Jobs::UpdateAssociatedGroupMemberships.new.execute

    group1.reload
    group2.reload
    group3.reload

    expect(group1.users.include?(user1)).to eq(true)
    expect(group2.users.include?(user1)).to eq(true)
    expect(group3.users.include?(user1)).to eq(false)

    expect(group1.users.include?(user3)).to eq(false)
    expect(group2.users.include?(user3)).to eq(true)
    expect(group3.users.include?(user3)).to eq(true)

    expect(group1.users.include?(user3)).to eq(false)
    expect(group2.users.include?(user3)).to eq(false)
    expect(group3.users.include?(user3)).to eq(true)
  end

end
