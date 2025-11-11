# frozen_string_literal: true

RSpec.describe ProblemCheck::AiCreditSoftLimit do
  subject(:check) { described_class.new(target) }

  fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

  before { SiteSetting.discourse_ai_enabled = true }

  describe "#call" do
    let(:target) { llm_model.id }

    it "returns no problems when no credit allocations exist" do
      expect(check).to be_chill_about_it
    end

    it "returns no problems when credits are not at soft limit" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 700,
        soft_limit_percentage: 80,
      )

      expect(check).to be_chill_about_it
    end

    it "returns soft limit problem when soft limit is reached" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 850,
        soft_limit_percentage: 80,
      )

      expect(check).to have_a_problem.with_priority("low").with_target(llm_model.id)
    end

    it "does not return soft limit problem when hard limit is reached" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1000,
        soft_limit_percentage: 80,
      )

      expect(check).to be_chill_about_it
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

      expect(check).to be_chill_about_it

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

      expect(check).to be_chill_about_it
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

      expect(check).to be_chill_about_it
    end
  end
end
