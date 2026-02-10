# frozen_string_literal: true

RSpec.describe Patreon::Patron do
  Fabricator(:patreon_user_info, class_name: :user_associated_account) do
    provider_name "patreon"
    user
  end

  fab!(:all_patrons_reward) do
    Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
  end
  fab!(:sponsors_reward) do
    Fabricate(:patreon_reward, patreon_id: "4589", title: "Sponsors", amount_cents: 1000)
  end
  fab!(:patron1) do
    Fabricate(:patreon_patron, patreon_id: "111111", email: "foo@bar.com", amount_cents: 100)
  end
  fab!(:patron2) do
    Fabricate(:patreon_patron, patreon_id: "111112", email: "boo@far.com", amount_cents: 500)
  end
  fab!(:patron3) do
    Fabricate(:patreon_patron, patreon_id: "111113", email: "roo@aar.com", amount_cents: nil)
  end

  before do
    Fabricate(:patreon_patron_reward, patreon_patron: patron1, patreon_reward: all_patrons_reward)
    Fabricate(:patreon_patron_reward, patreon_patron: patron2, patreon_reward: all_patrons_reward)
    Fabricate(:patreon_patron_reward, patreon_patron: patron2, patreon_reward: sponsors_reward)
  end

  it "should find local users matching Patreon user info" do
    Fabricate(:user, email: "foo@bar.com")
    Fabricate(:patreon_user_info, provider_uid: "111112")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(2)

    local_users.each do |user_id, patreon_id|
      user = User.find(user_id)
      patron = PatreonPatron.find_by(patreon_id: patreon_id)
      expect(described_class.attr("email", user)).to eq(patron.email)
      expect(described_class.attr("amount_cents", user)).to eq(patron.amount_cents)

      expected_titles =
        if patreon_id == "111111"
          "All Patrons"
        else
          "All Patrons, Sponsors"
        end
      expect(described_class.attr("rewards", user)).to eq(expected_titles)
    end
  end

  it "should find local users matching email address without case-sensitivity" do
    patron1.update!(email: "Foo@bar.com")
    Fabricate(:user, email: "foo@bar.com")

    local_users = described_class.get_local_users
    expect(local_users.count).to eq(1)
  end

  describe ".attr" do
    it "returns declined_since for a patron" do
      declined_time = 3.days.ago
      patron1.update!(declined_since: declined_time)
      user = Fabricate(:user, email: "foo@bar.com")
      user.custom_fields["patreon_id"] = "111111"
      user.save_custom_fields

      result = described_class.attr("declined_since", user)
      expect(result).to be_within(1.second).of(declined_time)
    end

    it "returns nil for declined_since when patron has not declined" do
      user = Fabricate(:user, email: "foo@bar.com")
      user.custom_fields["patreon_id"] = "111111"
      user.save_custom_fields

      expect(described_class.attr("declined_since", user)).to be_nil
    end

    it "returns the patreon_id for the default 'id' attribute" do
      user = Fabricate(:user, email: "foo@bar.com")
      user.custom_fields["patreon_id"] = "111111"
      user.save_custom_fields

      expect(described_class.attr("id", user)).to eq("111111")
    end

    it "returns nil when user has no patreon_id custom field" do
      user = Fabricate(:user)
      expect(described_class.attr("email", user)).to be_nil
    end
  end

  describe "sync groups" do
    let(:patreon_user_info) { Fabricate(:patreon_user_info, provider_uid: "111112") }
    let(:group1) { Fabricate(:group) }
    let(:group2) { Fabricate(:group) }

    before do
      SiteSetting.patreon_declined_pledges_grace_period_days = 7
      Fabricate(:patreon_group_reward_filter, group: group1, patreon_reward: all_patrons_reward)
      Fabricate(:patreon_group_reward_filter, group: group2, patreon_reward: sponsors_reward)
    end

    it "should sync all Patreon users" do
      user = Fabricate(:user, email: "foo@bar.com")
      described_class.sync_groups
      expect(group1.users.to_a - [patreon_user_info.user, user]).to eq([])
      expect(group2.users.to_a - [patreon_user_info.user]).to eq([])
    end

    it "should sync by Patreon id" do
      described_class.sync_groups_by(patreon_id: patreon_user_info.provider_uid)
      expect(group1.users.to_a).to eq([patreon_user_info.user])
      expect(group2.users.to_a).to eq([patreon_user_info.user])
    end

    it "should remove user from group when patron is no longer eligible" do
      user = patreon_user_info.user
      group1.add(user)
      expect(group1.users).to include(user)

      PatreonPatronReward.where(
        patreon_patron: patron2,
        patreon_reward: all_patrons_reward,
      ).delete_all
      PatreonPatronReward.where(patreon_patron: patron2, patreon_reward: sponsors_reward).delete_all

      described_class.sync_groups
      expect(group1.reload.users).not_to include(user)
      expect(group2.reload.users).not_to include(user)
    end

    it "should remove stale members when tier has zero patrons" do
      user = patreon_user_info.user
      group2.add(user)
      expect(group2.users).to include(user)

      PatreonPatronReward.where(patreon_reward: sponsors_reward).delete_all

      described_class.sync_groups
      expect(group2.reload.users).not_to include(user)
    end

    it "should remove user from group when pledge is declined beyond grace period" do
      user = patreon_user_info.user
      group1.add(user)

      patron2.update!(declined_since: 10.days.ago)

      described_class.sync_groups
      expect(group1.reload.users).not_to include(user)
    end

    it "should keep user in group when pledge is declined within grace period" do
      user = patreon_user_info.user

      patron2.update!(declined_since: 3.days.ago)

      described_class.sync_groups
      expect(group1.reload.users).to include(user)
    end

    describe "sync_groups_by" do
      it "should remove user when pledge is declined beyond grace period" do
        user = patreon_user_info.user
        group1.add(user)
        group2.add(user)

        patron2.update!(declined_since: 10.days.ago)

        described_class.sync_groups_by(patreon_id: "111112")
        expect(group1.reload.users).not_to include(user)
        expect(group2.reload.users).not_to include(user)
      end

      it "should keep user when pledge is declined within grace period" do
        user = patreon_user_info.user
        patron2.update!(declined_since: 3.days.ago)

        described_class.sync_groups_by(patreon_id: "111112")
        expect(group1.reload.users).to include(user)
      end

      it "should remove user from group when no longer in matching rewards" do
        user = patreon_user_info.user
        group2.add(user)

        PatreonPatronReward.where(
          patreon_patron: patron2,
          patreon_reward: sponsors_reward,
        ).delete_all

        described_class.sync_groups_by(patreon_id: "111112")
        expect(group2.reload.users).not_to include(user)
      end
    end
  end
end
