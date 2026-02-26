# frozen_string_literal: true

RSpec.describe Patreon::Pledge do
  fab!(:all_patrons_reward) do
    Fabricate(:patreon_reward, patreon_id: "0", title: "All Patrons", amount_cents: 0)
  end
  fab!(:premium_reward) do
    Fabricate(:patreon_reward, patreon_id: "999999", title: "Premium", amount_cents: 1000)
  end

  def build_pledge_data(patron_id:, email:, amount_cents:, reward_id: "999999", declined_since: nil)
    {
      "data" => [
        {
          "type" => "pledge",
          "id" => "pledge_#{patron_id}",
          "attributes" => {
            "amount_cents" => amount_cents,
            "declined_since" => declined_since,
          },
          "relationships" => {
            "patron" => {
              "data" => {
                "id" => patron_id,
                "type" => "user",
              },
            },
            "reward" => {
              "data" => {
                "id" => reward_id,
              },
            },
          },
        },
      ],
      "included" => [{ "type" => "user", "id" => patron_id, "attributes" => { "email" => email } }],
    }
  end

  def build_member_delete_data(patron_id:, tier_ids: [])
    {
      "data" => {
        "type" => "member",
        "id" => "member_#{patron_id}",
        "relationships" => {
          "user" => {
            "data" => {
              "id" => patron_id,
              "type" => "user",
            },
          },
          "currently_entitled_tiers" => {
            "data" => tier_ids.map { |id| { "id" => id, "type" => "tier" } },
          },
        },
      },
    }
  end

  describe ".save!" do
    it "upserts patrons and reward assignments" do
      data = build_pledge_data(patron_id: "p1", email: "a@b.com", amount_cents: 500)

      described_class.save!([data], true)

      patron = PatreonPatron.find_by(patreon_id: "p1")
      expect(patron.email).to eq("a@b.com")
      expect(patron.amount_cents).to eq(500)
      expect(patron.patreon_rewards).to include(premium_reward)
      expect(patron.patreon_rewards).to include(all_patrons_reward)
    end

    it "updates existing patron on second upsert" do
      data1 = build_pledge_data(patron_id: "p1", email: "a@b.com", amount_cents: 500)
      described_class.save!([data1], true)

      data2 = build_pledge_data(patron_id: "p1", email: "a@b.com", amount_cents: 999)
      described_class.save!([data2], true)

      expect(PatreonPatron.where(patreon_id: "p1").count).to eq(1)
      expect(PatreonPatron.find_by(patreon_id: "p1").amount_cents).to eq(999)
    end

    context "with full sync (is_append = false)" do
      it "prunes patrons not in the current sync" do
        Fabricate(:patreon_patron, patreon_id: "stale_patron", email: "stale@test.com")
        data =
          build_pledge_data(patron_id: "fresh_patron", email: "fresh@test.com", amount_cents: 100)

        described_class.save!([data], false)

        expect(PatreonPatron.find_by(patreon_id: "stale_patron")).to be_nil
        expect(PatreonPatron.find_by(patreon_id: "fresh_patron")).to be_present
      end

      it "clears all patrons and reward assignments when payload is empty" do
        patron = Fabricate(:patreon_patron, patreon_id: "old", email: "old@test.com")
        Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: premium_reward)

        described_class.save!([], false)

        expect(PatreonPatron.count).to eq(0)
        expect(PatreonPatronReward.count).to eq(0)
      end

      it "prunes orphaned reward assignments when patron switches tiers" do
        second_reward =
          Fabricate(:patreon_reward, patreon_id: "888888", title: "Basic", amount_cents: 100)

        data1 =
          build_pledge_data(
            patron_id: "p1",
            email: "a@b.com",
            amount_cents: 100,
            reward_id: "999999",
          )
        described_class.save!([data1], false)

        expect(
          PatreonPatron.find_by(patreon_id: "p1").patreon_rewards.pluck(:patreon_id),
        ).to include("999999")

        data2 =
          build_pledge_data(
            patron_id: "p1",
            email: "a@b.com",
            amount_cents: 100,
            reward_id: "888888",
          )
        described_class.save!([data2], false)

        patron = PatreonPatron.find_by(patreon_id: "p1")
        reward_ids = patron.patreon_rewards.pluck(:patreon_id)
        expect(reward_ids).to include("888888")
        expect(reward_ids).to include("0")
        expect(reward_ids).not_to include("999999")
      end
    end

    context "with append (is_append = true)" do
      it "does not prune existing patrons" do
        Fabricate(:patreon_patron, patreon_id: "existing", email: "existing@test.com")
        data = build_pledge_data(patron_id: "new_patron", email: "new@test.com", amount_cents: 100)

        described_class.save!([data], true)

        expect(PatreonPatron.find_by(patreon_id: "existing")).to be_present
        expect(PatreonPatron.find_by(patreon_id: "new_patron")).to be_present
      end

      it "does not clear patrons when payload is empty" do
        Fabricate(:patreon_patron, patreon_id: "keep_me", email: "keep@test.com")

        described_class.save!([], true)

        expect(PatreonPatron.find_by(patreon_id: "keep_me")).to be_present
      end

      it "preserves existing email when webhook payload omits it" do
        Fabricate(
          :patreon_patron,
          patreon_id: "p1",
          email: "original@test.com",
          amount_cents: 500,
          declined_since: 2.days.ago,
        )

        data = build_pledge_data(patron_id: "p1", email: nil, amount_cents: 999)
        described_class.save!([data], true)

        patron = PatreonPatron.find_by(patreon_id: "p1")
        expect(patron.amount_cents).to eq(999)
        expect(patron.email).to eq("original@test.com")
        # declined_since is explicitly nil in payload, meaning "not declined" — should be cleared
        expect(patron.declined_since).to be_nil
      end
    end
  end

  describe ".update!" do
    it "preserves existing email when webhook payload omits it" do
      Fabricate(
        :patreon_patron,
        patreon_id: "u1",
        email: "original@test.com",
        amount_cents: 500,
        declined_since: 2.days.ago,
      )
      Fabricate(
        :patreon_patron_reward,
        patreon_patron: PatreonPatron.find_by(patreon_id: "u1"),
        patreon_reward: premium_reward,
      )

      update_data =
        build_pledge_data(patron_id: "u1", email: nil, amount_cents: 999, reward_id: "999999")
      update_data["data"] = update_data["data"].first

      described_class.update!(update_data)

      patron = PatreonPatron.find_by(patreon_id: "u1")
      expect(patron.amount_cents).to eq(999)
      expect(patron.email).to eq("original@test.com")
      # declined_since nil in payload = "not declined" — should be cleared
      expect(patron.declined_since).to be_nil
      expect(patron.patreon_rewards).to include(premium_reward)
    end

    it "updates reward assignments when patron switches tiers" do
      basic_reward =
        Fabricate(:patreon_reward, patreon_id: "888888", title: "Basic", amount_cents: 100)
      patron = Fabricate(:patreon_patron, patreon_id: "u2", email: "u2@test.com", amount_cents: 100)
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: premium_reward)

      update_data =
        build_pledge_data(
          patron_id: "u2",
          email: "u2@test.com",
          amount_cents: 100,
          reward_id: "888888",
        )
      update_data["data"] = update_data["data"].first

      described_class.update!(update_data)

      patron.reload
      reward_ids = patron.patreon_rewards.pluck(:patreon_id)
      expect(reward_ids).to include("888888")
      expect(reward_ids).to include("0")
      expect(reward_ids).not_to include("999999")
    end

    it "clears declined_since when patron recovers from decline" do
      Fabricate(
        :patreon_patron,
        patreon_id: "u3",
        email: "u3@test.com",
        amount_cents: 500,
        declined_since: 10.days.ago,
      )

      update_data = build_pledge_data(patron_id: "u3", email: "u3@test.com", amount_cents: 500)
      update_data["data"] = update_data["data"].first

      described_class.update!(update_data)

      patron = PatreonPatron.find_by(patreon_id: "u3")
      expect(patron.declined_since).to be_nil
    end
  end

  describe ".safe_patreon_uri?" do
    it "accepts relative paths" do
      expect(described_class.safe_patreon_uri?("/oauth2/api/foo?page=2")).to eq(true)
    end

    it "accepts api.patreon.com URLs" do
      expect(
        described_class.safe_patreon_uri?("https://api.patreon.com/oauth2/api/foo?page=2"),
      ).to eq(true)
    end

    it "accepts www.patreon.com URLs" do
      expect(
        described_class.safe_patreon_uri?("https://www.patreon.com/api/oauth2/api/foo?page=2"),
      ).to eq(true)
    end

    it "rejects URLs to other hosts" do
      expect(described_class.safe_patreon_uri?("https://evil.com/steal")).to eq(false)
    end

    it "rejects malformed URIs" do
      expect(described_class.safe_patreon_uri?("ht tp://bad url")).to eq(false)
    end

    it "rejects HTTP URLs" do
      expect(described_class.safe_patreon_uri?("http://api.patreon.com/oauth2/api/foo")).to eq(
        false,
      )
    end

    it "rejects scheme-relative URLs" do
      expect(described_class.safe_patreon_uri?("//evil.com/steal")).to eq(false)
    end
  end

  describe ".delete!" do
    it "deletes a patron from pledge-type data" do
      Fabricate(:patreon_patron, patreon_id: "32187")

      pledge_data = {
        "data" => {
          "type" => "pledge",
          "relationships" => {
            "patron" => {
              "data" => {
                "id" => "32187",
                "type" => "user",
              },
            },
            "reward" => {
              "data" => {
                "id" => "999999",
              },
            },
          },
        },
      }

      expect { described_class.delete!(pledge_data) }.to change { PatreonPatron.count }.by(-1)
    end

    it "deletes a patron from member-type data" do
      Fabricate(:patreon_patron, patreon_id: "987654321")

      member_data = build_member_delete_data(patron_id: "987654321")

      expect { described_class.delete!(member_data) }.to change { PatreonPatron.count }.by(-1)
      expect(PatreonPatron.find_by(patreon_id: "987654321")).to be_nil
    end

    it "cascades to reward assignments when patron is deleted" do
      patron = Fabricate(:patreon_patron, patreon_id: "32187")
      Fabricate(:patreon_patron_reward, patreon_patron: patron, patreon_reward: premium_reward)

      pledge_data = {
        "data" => {
          "type" => "pledge",
          "relationships" => {
            "patron" => {
              "data" => {
                "id" => "32187",
                "type" => "user",
              },
            },
            "reward" => {
              "data" => {
                "id" => "999999",
              },
            },
          },
        },
      }

      expect { described_class.delete!(pledge_data) }.to change { PatreonPatronReward.count }.by(-1)
    end
  end
end
