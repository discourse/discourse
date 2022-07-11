# frozen_string_literal: true

require 'rails_helper'

describe UserCommScreener do
  fab!(:target_user1) { Fabricate(:user, username: "bobscreen") }
  fab!(:target_user2) { Fabricate(:user, username: "hughscreen") }
  fab!(:target_user3) { Fabricate(:user, username: "alicescreen") }
  fab!(:target_user4) { Fabricate(:user, username: "janescreen") }
  fab!(:target_user5) { Fabricate(:user, username: "maryscreen") }

  before do
    MutedUser.create!(user: target_user1, muted_user: acting_user)
    IgnoredUser.create!(user: target_user2, ignored_user: acting_user, expiring_at: 2.days.from_now)
    target_user3.user_option.update(allow_private_messages: false)
  end

  subject { described_class.new(
    acting_user, target_usernames: ["bobscreen", "hughscreen", "alicescreen", "janescreen", "maryscreen"])
  }

  context "when the actor is not staff" do
    fab!(:acting_user) { Fabricate(:user) }

    describe "allowing_actor_communication" do
      it "returns the usernames of people not ignoring, muting, or disallowing PMs from the actor" do
        expect(subject.allowing_actor_communication).to eq(["janescreen", "maryscreen"])
      end
    end

    describe "preventing_actor_communication" do
      it "returns the usernames of people ignoring, muting, or disallowing PMs from the actor" do
        expect(subject.preventing_actor_communication).to eq(["bobscreen", "hughscreen", "alicescreen"])
      end
    end

    describe "ignoring_or_muting_actor?" do
      it "does not raise an error when looking for a user who has no communication preferences" do
        expect(subject.ignoring_or_muting_actor?(target_user5.id)).to eq(false)
      end

      it "returns true for a user muting the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user ignoring the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user2.id)).to eq(true)
      end

      it "returns false for a user doing neither to the actor" do
        expect(subject.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end
    end

    describe "disallowing_pms_from_actor?" do
      it "returns true for a user disallowing all PMs" do
        expect(subject.disallowing_pms_from_actor?(target_user3.id)).to eq(true)
      end

      it "returns true for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update(enable_allowed_pm_users: true)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(true)
      end

      it "returns false for a user allowing only PMs for certain users with the actor allowed" do
        target_user4.user_option.update(enable_allowed_pm_users: true)
        AllowedPmUser.create(user: target_user4, allowed_pm_user: acting_user)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns true for a user not disallowing PMs but still ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user1.id)).to eq(true)
      end

      it "returns true for a user not disallowing PMs but still muting" do
        expect(subject.disallowing_pms_from_actor?(target_user2.id)).to eq(true)
      end
    end
  end

  context "when the actor is staff" do
    fab!(:acting_user) { Fabricate(:admin) }

    describe "allowing_actor_communication" do
      it "returns all usernames since staff can communicate with anyone" do
        expect(subject.allowing_actor_communication).to eq(["bobscreen", "hughscreen", "alicescreen", "janescreen", "maryscreen"])
      end
    end

    describe "preventing_actor_communication" do
      it "returns [] since no users can prevent staff communicating with them" do
        expect(subject.preventing_actor_communication).to eq([])
      end
    end

    describe "ignoring_or_muting_actor?" do
      it "returns false for a user muting the staff" do
        expect(subject.ignoring_or_muting_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user ignoring the staff actor" do
        expect(subject.ignoring_or_muting_actor?(target_user2.id)).to eq(false)
      end

      it "returns false for a user doing neither to the staff actor" do
        expect(subject.ignoring_or_muting_actor?(target_user3.id)).to eq(false)
      end
    end

    describe "disallowing_pms_from_actor?" do
      it "returns false for a user disallowing all PMs" do
        expect(subject.disallowing_pms_from_actor?(target_user3.id)).to eq(false)
      end

      it "returns false for a user allowing only PMs for certain users but not the actor" do
        target_user4.user_option.update(enable_allowed_pm_users: true)
        expect(subject.disallowing_pms_from_actor?(target_user4.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs or muting or ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user5.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still ignoring" do
        expect(subject.disallowing_pms_from_actor?(target_user1.id)).to eq(false)
      end

      it "returns false for a user not disallowing PMs but still muting" do
        expect(subject.disallowing_pms_from_actor?(target_user2.id)).to eq(false)
      end
    end
  end
end
