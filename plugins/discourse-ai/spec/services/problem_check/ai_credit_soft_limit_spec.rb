# frozen_string_literal: true

RSpec.describe ProblemCheck::AiCreditSoftLimit do
  fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

  before { SiteSetting.discourse_ai_enabled = true }

  describe "#call" do
    it "returns no problems when no credit allocations exist" do
      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "returns no problems when credits are not at soft limit" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 700,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "returns soft limit problem when soft limit is reached" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 850,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems.size).to eq(1)
      expect(problems.first.identifier).to eq(:ai_credit_soft_limit)
      expect(problems.first.priority).to eq("low")
      expect(problems.first.target).to eq(llm_model.id)
    end

    it "does not return soft limit problem when hard limit is reached" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1000,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end

    it "does not report problem when previous month exceeded limit but current month is new" do
      freeze_time(Time.zone.parse("2025-10-15 14:30:00"))
      allocation =
        Fabricate(
          :llm_credit_allocation,
          llm_model: llm_model,
          monthly_credits: 1000,
          monthly_used: 850,
          soft_limit_percentage: 80,
        )

      freeze_time(Time.zone.parse("2025-11-05 10:00:00"))
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
        monthly_used: 850,
        soft_limit_percentage: 80,
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
        monthly_used: 850,
        soft_limit_percentage: 80,
      )

      problems = described_class.new.call

      expect(problems).to be_empty
    end
  end
end
