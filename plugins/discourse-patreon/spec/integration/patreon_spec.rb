# frozen_string_literal: true

RSpec.describe Patreon do
  describe "donation prompt" do
    let(:user1) { Fabricate(:user) }
    let(:user2) { Fabricate(:user) }
    let(:group) { Fabricate(:group) }

    before do
      SiteSetting.patreon_enabled = true
      reward = Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
      Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: reward)
      group.add(user1)
    end

    context "with donation prompt enabled" do
      before { SiteSetting.patreon_donation_prompt_enabled = true }

      it "should not show donation prompt to patrons" do
        expect(described_class.show_donation_prompt_to_user?(user1)).to eq(false)
      end

      it "should show donation prompt to non-patrons" do
        expect(described_class.show_donation_prompt_to_user?(user2)).to eq(true)
      end
    end

    context "with donation prompt disabled" do
      before { SiteSetting.patreon_donation_prompt_enabled = false }

      it "should show donation prompt to non-patrons" do
        expect(described_class.show_donation_prompt_to_user?(user2)).to eq(false)
      end
    end
  end

  describe "user_created callback logic" do
    fab!(:all_patrons_reward) do
      Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
    end
    fab!(:premium_reward) do
      Fabricate(:patreon_reward, patreon_id: "9999", title: "Premium", amount_cents: 1000)
    end
    fab!(:patron_group, :group)

    before do
      Fabricate(
        :patreon_group_reward_filter,
        group: patron_group,
        patreon_reward: all_patrons_reward,
      )
    end

    def trigger_user_created(user)
      DiscourseEvent.trigger(:user_created, user)
    end

    before { SiteSetting.patreon_enabled = true }

    it "adds new user to groups when patron email matches" do
      patron =
        Fabricate(
          :patreon_patron,
          patreon_id: "abc123",
          email: "newuser@example.com",
          amount_cents: 500,
        )
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: all_patrons_reward)

      user = Fabricate(:user, email: "newuser@example.com")
      trigger_user_created(user)

      expect(patron_group.reload.users).to include(user)
      expect(user.custom_fields["patreon_id"]).to eq("abc123")
    end

    it "adds user to multiple groups based on reward tiers" do
      premium_group = Fabricate(:group)
      Fabricate(:patreon_group_reward_filter, group: premium_group, patreon_reward: premium_reward)

      patron =
        Fabricate(
          :patreon_patron,
          patreon_id: "abc456",
          email: "premium@example.com",
          amount_cents: 1000,
        )
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: all_patrons_reward)
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: premium_reward)

      user = Fabricate(:user, email: "premium@example.com")
      trigger_user_created(user)

      expect(patron_group.reload.users).to include(user)
      expect(premium_group.reload.users).to include(user)
    end

    it "does not add user to groups when no patron matches" do
      user = Fabricate(:user, email: "nobody@example.com")
      trigger_user_created(user)

      expect(patron_group.reload.users.count).to eq(0)
    end

    it "does not add user when no filters are configured" do
      PatreonGroupRewardFilter.delete_all

      patron =
        Fabricate(
          :patreon_patron,
          patreon_id: "abc789",
          email: "nofilter@example.com",
          amount_cents: 100,
        )
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: all_patrons_reward)

      user = Fabricate(:user, email: "nofilter@example.com")
      trigger_user_created(user)

      expect(patron_group.reload.users.count).to eq(0)
    end

    it "does not add user to groups when plugin is disabled" do
      SiteSetting.patreon_enabled = false

      patron =
        Fabricate(
          :patreon_patron,
          patreon_id: "abc_disabled",
          email: "disabled@example.com",
          amount_cents: 500,
        )
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: all_patrons_reward)

      user = Fabricate(:user, email: "disabled@example.com")
      trigger_user_created(user)

      expect(patron_group.reload.users).not_to include(user)
    end
  end

  describe "when plugin is disabled" do
    before { SiteSetting.patreon_enabled = false }

    it "does not show donation prompt even with sub-setting enabled" do
      SiteSetting.patreon_donation_prompt_enabled = true
      group = Fabricate(:group)
      reward = Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
      Fabricate(:patreon_group_reward_filter, group: group, patreon_reward: reward)
      user = Fabricate(:user)

      expect(described_class.show_donation_prompt_to_user?(user)).to eq(false)
    end

    it "does not include patreon fields in admin user serializer" do
      admin = Fabricate(:admin)
      user = Fabricate(:user)
      Fabricate(:patreon_patron, patreon_id: "ser123", email: "ser@test.com", amount_cents: 500)
      user.custom_fields["patreon_id"] = "ser123"
      user.save_custom_fields

      sign_in(admin)
      get "/admin/users/#{user.id}.json"

      body = response.parsed_body
      expect(body).not_to have_key("patreon_id")
      expect(body).not_to have_key("patreon_amount_cents")
      expect(body).not_to have_key("patreon_email_exists")
    end
  end
end
