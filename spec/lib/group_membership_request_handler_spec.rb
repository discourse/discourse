# frozen_string_literal: true

describe GroupMembershipRequestHandler do
  fab!(:user)
  fab!(:owner, :user)
  fab!(:group)

  before do
    group.add_owner(owner)
    group.update!(allow_membership_requests: true)
    GroupMembershipRequester.request(user.guardian, group, "I write the docs")
  end

  describe ".handle" do
    it "adds the requester, clears the request, and replies in the request message" do
      expect { described_class.handle(owner.guardian, group, user, accept: true) }.to change {
        GroupRequest.count
      }.by(-1)

      expect(group.reload.users).to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:add_user_to_group],
          target_user: user,
        ),
      ).to eq(true)
      request_topic = Topic.private_messages.last
      expect(request_topic.posts.last.raw).to eq(
        I18n.t("groups.request_accepted_pm.body", group_name: group.name).strip,
      )
    end

    it "clears the request without adding the user when denied" do
      expect { described_class.handle(owner.guardian, group, user, accept: false) }.to change {
        GroupRequest.count
      }.by(-1)

      expect(group.reload.users).not_to include(user)
    end

    it "refuses a user who cannot edit the group" do
      expect {
        described_class.handle(Fabricate(:user).guardian, group, user, accept: true)
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "still accepts the request when the original message is gone" do
      Topic.private_messages.last.destroy!

      expect { described_class.handle(owner.guardian, group, user, accept: true) }.to change {
        GroupRequest.count
      }.by(-1)
      expect(group.reload.users).to include(user)
    end
  end
end
