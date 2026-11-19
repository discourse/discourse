# frozen_string_literal: true

describe UserApprover do
  fab!(:moderator)

  describe ".approve" do
    it "approves a user through the reviewable workflow" do
      SiteSetting.must_approve_users = true
      unapproved_user = Fabricate(:user, approved: false)

      described_class.approve(moderator.guardian, unapproved_user)

      expect(unapproved_user.reload).to be_approved
      expect(ReviewableUser.find_by(target: unapproved_user)).to be_approved
      expect(
        UserHistory.where(
          action: UserHistory.actions[:approve_user],
          acting_user_id: moderator.id,
          target_user_id: unapproved_user.id,
        ),
      ).to exist
    end
  end
end
