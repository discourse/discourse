# frozen_string_literal: true

require 'rails_helper'

describe Jobs::AutomaticGroupMembership do

  it "raises an error when the group id is missing" do
    expect { Jobs::AutomaticGroupMembership.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "updates the membership" do
    user1 = Fabricate(:user, email: "no@bar.com")
    user2 = Fabricate(:user, email: "no@wat.com")
    user3 = Fabricate(:user, email: "noo@wat.com", staged: true)
    EmailToken.confirm(user3.email_tokens.last.token)
    user4 = Fabricate(:user, email: "yes@wat.com")
    EmailToken.confirm(user4.email_tokens.last.token)
    user5 = Fabricate(:user, email: "sso@wat.com")
    user5.create_single_sign_on_record(external_id: 123, external_email: "hacker@wat.com", last_payload: "")
    user6 = Fabricate(:user, email: "sso2@wat.com")
    user6.create_single_sign_on_record(external_id: 456, external_email: "sso2@wat.com", last_payload: "")

    group = Fabricate(:group, automatic_membership_email_domains: "wat.com", automatic_membership_retroactive: true)

    begin
      automatic = nil
      called = false

      DiscourseEvent.on(:user_added_to_group) do |_u, _g, options|
        automatic = options[:automatic]
        called = true
      end

      Jobs::AutomaticGroupMembership.new.execute(group_id: group.id)

      expect(automatic).to eql(true)
      expect(called).to eq(true)
    ensure
      DiscourseEvent.off(:user_added_to_group)
    end

    group.reload
    expect(group.users.include?(user1)).to eq(false)
    expect(group.users.include?(user2)).to eq(false)
    expect(group.users.include?(user3)).to eq(false)
    expect(group.users.include?(user4)).to eq(true)
    expect(group.users.include?(user5)).to eq(false)
    expect(group.users.include?(user6)).to eq(true)
  end

end
