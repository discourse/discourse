require 'rails_helper'
require_dependency 'jobs/regular/automatic_group_membership'

describe Jobs::AutomaticGroupMembership do

  it "raises an error when the group id is missing" do
    expect { Jobs::AutomaticGroupMembership.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "updates the membership" do
    user1 = Fabricate(:user, email: "no@bar.com")
    user2 = Fabricate(:user, email: "no@wat.com")
    user3 = Fabricate(:user, email: "noo@wat.com", staged: true)
    user4 = Fabricate(:user, email: "yes@wat.com")
    EmailToken.confirm(user4.email_tokens.last.token)

    group = Fabricate(:group, automatic_membership_email_domains: "wat.com", automatic_membership_retroactive: true)

    Jobs::AutomaticGroupMembership.new.execute(group_id: group.id)

    group.reload
    expect(group.users.include?(user1)).to eq(false)
    expect(group.users.include?(user2)).to eq(false)
    expect(group.users.include?(user3)).to eq(false)
    expect(group.users.include?(user4)).to eq(true)
  end

end
