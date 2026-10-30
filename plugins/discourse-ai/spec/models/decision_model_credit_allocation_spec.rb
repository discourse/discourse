# frozen_string_literal: true

RSpec.describe DecisionModelCreditAllocation do
  fab!(:decision_model) { Fabricate(:decision_model, id: -1) }

  before { enable_current_plugin }

  describe ".check_credits!" do
    it "raises a decision error once the daily allocation is used up" do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model:,
        daily_credits: 1000,
        daily_used: 1000,
      )

      expect { described_class.check_credits!(decision_model, "workflow") }.to raise_error(
        DiscourseAi::Decisions::CreditLimitExceeded,
        /#{decision_model.display_name}/,
      )
    end

    it "allows requests while credits remain" do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model:,
        daily_credits: 1000,
        daily_used: 999,
      )

      expect { described_class.check_credits!(decision_model, "workflow") }.not_to raise_error
    end

    it "allows free features and models without a seeded allocation once credits are used up" do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model:,
        daily_credits: 1000,
        daily_used: 1000,
      )
      DecisionModelFeatureCreditCost.create!(
        decision_model:,
        feature_name: "workflow",
        credits_per_token: 0,
      )
      unseeded_model = Fabricate(:decision_model)
      DecisionModelCreditAllocation.create!(decision_model: unseeded_model, daily_credits: 1)
      DecisionModelCreditDailyUsage.increment_usage!(unseeded_model, 5)

      expect { described_class.check_credits!(decision_model, "workflow") }.not_to raise_error
      expect { described_class.check_credits!(unseeded_model, "workflow") }.not_to raise_error
    end
  end

  describe ".credits_available?" do
    it "is false only once a charged feature has used up the daily allocation" do
      Fabricate(
        :decision_model_credit_allocation,
        decision_model:,
        daily_credits: 1000,
        daily_used: 1000,
      )
      DecisionModelFeatureCreditCost.create!(
        decision_model:,
        feature_name: "free_feature",
        credits_per_token: 0,
      )

      expect(described_class.credits_available?(decision_model, "workflow")).to eq(false)
      expect(described_class.credits_available?(decision_model, "free_feature")).to eq(true)
    end
  end

  describe ".deduct_credits!" do
    fab!(:allocation) do
      Fabricate(:decision_model_credit_allocation, decision_model:, daily_credits: 1000)
    end

    it "charges one credit per token by default and accumulates across calls" do
      described_class.deduct_credits!(decision_model, "workflow", 120)
      described_class.deduct_credits!(decision_model, "workflow", 30)

      expect(allocation.reload.daily_used).to eq(150)
    end

    it "applies the feature cost, falling back to the default cost, rounding up" do
      DecisionModelFeatureCreditCost.create!(
        decision_model:,
        feature_name: "workflow",
        credits_per_token: 0.25,
      )
      DecisionModelFeatureCreditCost.create!(
        decision_model:,
        feature_name: "default",
        credits_per_token: 2,
      )

      described_class.deduct_credits!(decision_model, "workflow", 9)
      described_class.deduct_credits!(decision_model, "other_feature", 10)

      expect(allocation.reload.daily_used).to eq(3 + 20)
    end

    it "keeps each day's usage separate so credits reset at midnight UTC" do
      freeze_time(Time.utc(2026, 10, 15, 23, 0))
      described_class.deduct_credits!(decision_model, "workflow", 1000)
      expect(allocation.reload.hard_limit_reached?).to eq(true)

      freeze_time(Time.utc(2026, 10, 16, 0, 1))
      expect(allocation.reload.hard_limit_reached?).to eq(false)
      expect(allocation.percentage_remaining).to eq(100.0)
    end
  end

  describe "#soft_limit_reached?" do
    it "is reached when usage meets the soft limit percentage" do
      allocation =
        Fabricate(
          :decision_model_credit_allocation,
          decision_model:,
          daily_credits: 1000,
          daily_used: 800,
          soft_limit_percentage: 80,
        )

      expect(allocation).to have_attributes(
        soft_limit_reached?: true,
        hard_limit_reached?: false,
        credits_remaining: 200,
        percentage_remaining: 20.0,
      )
    end
  end
end
