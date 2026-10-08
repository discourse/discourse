# frozen_string_literal: true

describe GroupSelfMembership do
  fab!(:user)
  fab!(:group) { Fabricate(:group, public_admission: true, public_exit: true) }

  describe ".join" do
    it "adds the user and logs the change" do
      expect(described_class.join(user.guardian, group)).to eq(true)
      expect(group.reload.users).to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:add_user_to_group],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "reports no change when the user is already a member" do
      group.add(user)

      expect(described_class.join(user.guardian, group)).to eq(false)
    end

    it "refuses a group that does not allow public admission" do
      group.update!(public_admission: false)

      expect { described_class.join(user.guardian, group) }.to raise_error(Discourse::InvalidAccess)
    end

    it "refuses an anonymous caller" do
      expect { described_class.join(Guardian.new, group) }.to raise_error(Discourse::NotLoggedIn)
    end

    it "rate limits a regular user" do
      RateLimiter.enable
      RateLimiter.any_instance.stubs(:rate_unlimited?).returns(false)

      3.times { described_class.join(user.guardian, Fabricate(:group, public_admission: true)) }

      expect { described_class.join(user.guardian, group) }.to raise_error(
        RateLimiter::LimitExceeded,
      )
    end
  end

  describe ".leave" do
    before { group.add(user) }

    it "removes the user and logs the change" do
      expect(described_class.leave(user.guardian, group)).to eq(true)
      expect(group.reload.users).not_to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:remove_user_from_group],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "refuses a group that does not allow public exit" do
      group.update!(public_exit: false)

      expect { described_class.leave(user.guardian, group) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "reports no change when the user is not a member" do
      expect(described_class.leave(Fabricate(:user).guardian, group)).to eq(false)
    end
  end
end
