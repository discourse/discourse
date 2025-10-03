# frozen_string_literal: true

RSpec.describe ProblemCheck::AiCreditHardLimit do
  fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

  before { SiteSetting.discourse_ai_enabled = true }

  describe "#call" do
    it "returns no problems when no credit allocations exist" do
      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "returns no problems when credits are not exhausted" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 850,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "returns hard limit problem when credits are exhausted" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1000,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems.size).to eq(1)
      expect(problems.first.identifier).to eq("ai_credit_hard_limit")
      expect(problems.first.priority).to eq("high")
      expect(problems.first.target).to eq(llm_model.id)
    end

    it "returns hard limit problem when credits are over-exhausted" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1200,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems.size).to eq(1)
      expect(problems.first.identifier).to eq("ai_credit_hard_limit")
    end

    it "resets credits before checking if needed" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          llm_model: llm_model,
          monthly_credits: 1000,
          monthly_used: 1000,
          last_reset_at: 2.months.ago,
          soft_limit_percentage: 80,
        )

      problems = described_class.new.call

      expect(problems).to be_empty
      allocation.reload
      expect(allocation.monthly_used).to eq(0)
    end

    it "skips non-seeded models" do
      non_seeded = Fabricate(:llm_model, id: 1)
      Fabricate(
        :llm_credit_allocation,
        llm_model: non_seeded,
        monthly_credits: 1000,
        monthly_used: 1000,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "returns no problems when discourse_ai is disabled" do
      SiteSetting.discourse_ai_enabled = false
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1000,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end
  end
end
