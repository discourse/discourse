# frozen_string_literal: true

describe GroupMembershipRequester do
  fab!(:user)
  fab!(:owner, :user)
  fab!(:group)

  before do
    group.add_owner(owner)
    group.update!(allow_membership_requests: true)
  end

  describe ".request" do
    it "records the request and messages the group owners" do
      post = described_class.request(user.guardian, group, "I write the docs")

      expect(GroupRequest.find_by(group:, user:).reason).to eq("I write the docs")
      expect(post.topic.archetype).to eq(Archetype.private_message)
      expect(post.topic.allowed_users).to include(user, owner)
      expect(post.topic.custom_fields["requested_group_id"]).to eq(group.id.to_s)
    end

    it "refuses a group that does not allow requests" do
      group.update!(allow_membership_requests: false)

      expect { described_class.request(user.guardian, group, "please") }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "refuses an existing member" do
      group.add(user)

      expect { described_class.request(user.guardian, group, "please") }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "refuses a second request from the same user" do
      described_class.request(user.guardian, group, "please")

      expect { described_class.request(user.guardian, group, "again") }.to raise_error(
        GroupMembershipRequester::AlreadyRequested,
      )
    end

    it "refuses an anonymous caller" do
      expect { described_class.request(Guardian.new, group, "please") }.to raise_error(
        Discourse::NotLoggedIn,
      )
    end
  end
end
