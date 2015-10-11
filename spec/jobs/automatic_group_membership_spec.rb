require 'rails_helper'
require_dependency 'jobs/regular/automatic_group_membership'

describe Jobs::AutomaticGroupMembership do

  it "raises an error when the group id is missing" do
    expect { Jobs::AutomaticGroupMembership.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "updates the membership" do
    user1 = Fabricate(:user, email: "foo@wat.com")
    user2 = Fabricate(:user, email: "foo@bar.com")
    group = Fabricate(:group, automatic_membership_email_domains: "wat.com", automatic_membership_retroactive: true)

    Jobs::AutomaticGroupMembership.new.execute(group_id: group.id)

    group.reload
    expect(group.users.include?(user1)).to eq(true)
    expect(group.users.include?(user2)).to eq(false)
  end

end
