# frozen_string_literal: true

RSpec.describe UserCommScreener do
  subject(:screener) do
    described_class.new(
      acting_user: acting_user,
      target_user_ids: [
        target_user1.id,
        target_user2.id,
        target_user3.id,
        target_user4.id,
        target_user5.id,
      ],
    )
  end

  fab!(:target_user1) { Fabricate(:user, username: "bobscreen") }
  fab!(:target_user2) { Fabricate(:user, username: "hughscreen") }
  fab!(:target_user3) do
    user = Fabricate(:user, username: "alicescreen")
    user.user_option.update(allow_private_messages: false)
    user
  end
  fab!(:target_user4) { Fabricate(:user, username: "janescreen") }
  fab!(:target_user5) { Fabricate(:user, username: "maryscreen") }
  fab!(:other_user) { Fabricate(:user) }

  it "allows initializing the class with both an acting_user_id and an acting_user" do
    acting_user = Fabricate(:user)
    screener = described_class.new(acting_user: acting_user, target_user_ids: [target_user1.id])
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
    screener =
      described_class.new(acting_user_id: acting_user.id, target_user_ids: [target_user1.id])
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
  end

  it "filters out the acting user from target_user_ids" do
    acting_user = Fabricate(:user)
    screener =
      described_class.new(
        acting_user: acting_user,
        target_user_ids: [target_user1.id, acting_user.id],
      )
    expect(screener.allowing_actor_communication).to eq([target_user1.id])
  end

  context "when the actor is not staff" do
    fab!(:acting_user) { Fabricate(:user) }
    fab!(:muted_user) { Fabricate(:muted_user, user: target_user1, muted_user: acting_user) }
    fab!(:ignored_user) do
      Fabricate(
        :ignored_user,
        user: target_user2,
        ignored_user: acting_user,
        expiring_at: 2.days.from_now,
      )
    end

    describe "#allowing_actor_communication" do
      it "returns the usernames of people not ignoring, muting, or disallowing PMs from the actor" do
        expect(screener.allowing_actor_communication).to match_array(
          [target_user4.id, target_user5.id],
        )
      end
    end

    describe "#preventing_actor_communication" do
      it "returns the usernames of people ignoring, muting, or disallowing PMs from the actor" do
        expect(screener.preventing_actor_communication).to match_array(
          [target_user1.id, target_user2.id, target_user3.id],
        )
      end
    end

    describe "#ignoring_or_muting_actor?" do
      it "does not raise an error when looking for a user who has no communication preferences" do
        expect { screener.ignoring_or_muting_actor?(target_user5.id) }.not_to raise_error
      end

      it "returns true for a user muting the actor" do
        expect(screener.ignoring_or_muting_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user ignoring the actor" do
        expect(screener.ignoring_or_muting_actor?(target_user2.id)).to eq(true)
      end

      it "returns false for a user neither ignoring or muting the actor" do
        expect(screener.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.ignoring_or_muting_actor?(other_user.id) }.to raise_error(
          Discourse::NotFound,
        )
      end
    end

    describe "#disallowing_pms_from_actor?" do
      it "returns true for a user disallowing all PMs" do
        expect(screener.disallowing_pms_from_actor?(target_user3.id)).to eq(true)
      end

      it "returns true for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        expect(screener.disallowing_pms_from_actor?(target_user4.id)).to eq(true)
      end

      it "returns false for a user allowing only PMs for certain users which the actor allowed" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        AllowedPmUser.create!(user: target_user4, allowed_pm_user: acting_user)
        expect(screener.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(screener.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns true for a user not disallowing PMs but still ignoring" do
        expect(screener.disallowing_pms_from_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user not disallowing PMs but still muting" do
        expect(screener.disallowing_pms_from_actor?(target_user2.id)).to eq(true)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.disallowing_pms_from_actor?(other_user.id) }.to raise_error(
          Discourse::NotFound,
        )
      end
    end
  end

  context "when the actor is staff" do
    fab!(:acting_user) { Fabricate(:admin) }
    fab!(:muted_user) { Fabricate(:muted_user, user: target_user1, muted_user: acting_user) }
    fab!(:ignored_user) do
      Fabricate(
        :ignored_user,
        user: target_user1,
        ignored_user: acting_user,
        expiring_at: 2.days.from_now,
      )
    end

    describe "#allowing_actor_communication" do
      it "returns all usernames since staff can communicate with anyone" do
        expect(screener.allowing_actor_communication).to match_array(
          [target_user1.id, target_user2.id, target_user3.id, target_user4.id, target_user5.id],
        )
      end
    end

    describe "#preventing_actor_communication" do
      it "does not return any usernames since no users can prevent staff communicating with them" do
        expect(screener.preventing_actor_communication).to eq([])
      end
    end

    describe "#ignoring_or_muting_actor?" do
      it "returns false for a user muting the staff" do
        expect(screener.ignoring_or_muting_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user ignoring the staff actor" do
        expect(screener.ignoring_or_muting_actor?(target_user2.id)).to eq(false)
      end

      it "returns false for a user neither ignoring or muting the actor" do
        expect(screener.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.ignoring_or_muting_actor?(other_user.id) }.to raise_error(
          Discourse::NotFound,
        )
      end
    end

    describe "#disallowing_pms_from_actor?" do
      it "returns false for a user disallowing all PMs" do
        expect(screener.disallowing_pms_from_actor?(target_user3.id)).to eq(false)
      end

      it "returns false for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update!(enable_allowed_pm_users: true)
        expect(screener.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(screener.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still ignoring" do
        expect(screener.disallowing_pms_from_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still muting" do
        expect(screener.disallowing_pms_from_actor?(target_user2.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.disallowing_pms_from_actor?(other_user.id) }.to raise_error(
          Discourse::NotFound,
        )
      end
    end
  end

  describe "actor preferences" do
    fab!(:acting_user) { Fabricate(:user) }
    fab!(:muted_user) { Fabricate(:muted_user, user: acting_user, muted_user: target_user1) }
    fab!(:ignored_user) do
      Fabricate(
        :ignored_user,
        user: acting_user,
        ignored_user: target_user2,
        expiring_at: 2.days.from_now,
      )
    end
    fab!(:allowed_pm_user1) do
      AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user1)
    end
    fab!(:allowed_pm_user2) do
      AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user2)
    end
    fab!(:allowed_pm_user3) do
      AllowedPmUser.create!(user: acting_user, allowed_pm_user: target_user4)
    end

    describe "#actor_preventing_communication" do
      it "returns the user_ids of the users the actor is ignoring, muting, or disallowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(screener.actor_preventing_communication).to match_array(
          [target_user1.id, target_user2.id, target_user3.id, target_user5.id],
        )
      end

      it "does not include users the actor is disallowing PMs from if they have not set enable_allowed_pm_users" do
        expect(screener.actor_preventing_communication).to match_array(
          [target_user1.id, target_user2.id],
        )
      end

      describe "when the actor has no preferences" do
        before do
          muted_user.destroy
          ignored_user.destroy
        end

        it "returns an empty array and does not error" do
          expect(screener.actor_preventing_communication).to match_array([])
        end
      end
    end

    describe "#actor_allowing_communication" do
      it "returns the user_ids of the users who the actor is not ignoring, muting, or disallowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(screener.actor_allowing_communication).to match_array([target_user4.id])
      end

      describe "when the actor has no preferences" do
        before do
          muted_user.destroy
          ignored_user.destroy
        end

        it "returns an array of the target users and does not error" do
          expect(screener.actor_allowing_communication).to match_array(
            [target_user1.id, target_user2.id, target_user3.id, target_user4.id, target_user5.id],
          )
        end
      end
    end

    describe "#actor_ignoring?" do
      it "returns true for user ids that the actor is ignoring" do
        expect(screener.actor_ignoring?(target_user2.id)).to eq(true)
        expect(screener.actor_ignoring?(target_user4.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.actor_ignoring?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#actor_muting?" do
      it "returns true for user ids that the actor is muting" do
        expect(screener.actor_muting?(target_user1.id)).to eq(true)
        expect(screener.actor_muting?(target_user2.id)).to eq(false)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.actor_muting?(other_user.id) }.to raise_error(Discourse::NotFound)
      end
    end

    describe "#actor_disallowing_pms?" do
      it "returns true for user ids that the actor is not explicitly allowing PMs from" do
        acting_user.user_option.update!(enable_allowed_pm_users: true)
        expect(screener.actor_disallowing_pms?(target_user3.id)).to eq(true)
        expect(screener.actor_disallowing_pms?(target_user1.id)).to eq(false)
      end

      it "returns true if the actor has disallowed all PMs" do
        acting_user.user_option.update!(allow_private_messages: false)
        expect(screener.actor_disallowing_pms?(target_user3.id)).to eq(true)
        expect(screener.actor_disallowing_pms?(target_user1.id)).to eq(true)
      end

      it "raises a NotFound error if the user_id passed in is not part of the target users" do
        expect { screener.actor_disallowing_pms?(other_user.id) }.to raise_error(
          Discourse::NotFound,
        )
      end
    end

    describe "#actor_disallowing_all_pms?" do
      it "returns true if the acting user has disabled private messages altogether" do
        expect(screener.actor_disallowing_all_pms?).to eq(false)
        acting_user.user_option.update!(allow_private_messages: false)
        expect(screener.actor_disallowing_all_pms?).to eq(true)
      end
    end
  end
end
