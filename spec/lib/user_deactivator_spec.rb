# frozen_string_literal: true

describe UserDeactivator do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe ".deactivate" do
    it "deactivates a regular user and records the staff action" do
      expect do described_class.deactivate(moderator.guardian, user) end.to change {
        UserHistory.where(
          action: UserHistory.actions[:deactivate_user],
          acting_user_id: moderator.id,
          target_user_id: user.id,
        ).count
      }.by(1)

      expect(user.reload).not_to be_active
    end

    it "does not let a moderator deactivate a staff user" do
      expect do described_class.deactivate(moderator.guardian, admin) end.to raise_error(
        Discourse::InvalidAccess,
      )

      expect(admin.reload).to be_active
    end
  end
end
