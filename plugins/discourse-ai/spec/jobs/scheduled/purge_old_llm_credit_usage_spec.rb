# frozen_string_literal: true

RSpec.describe Jobs::PurgeOldLlmCreditUsage do
  fab!(:llm_model)

  before { SiteSetting.discourse_ai_enabled = true }

  it "deletes records older than retention period" do
    old_date = 100.days.ago.to_date
    recent_date = 50.days.ago.to_date

    old_usage =
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: old_date, credits_used: 100)

    recent_usage =
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: recent_date, credits_used: 200)

    described_class.new.execute({})

    expect(LlmCreditDailyUsage.exists?(old_usage.id)).to be false
    expect(LlmCreditDailyUsage.exists?(recent_usage.id)).to be true
  end

  it "keeps records within retention period" do
    within_retention = 80.days.ago.to_date

    usage =
      LlmCreditDailyUsage.create!(
        llm_model: llm_model,
        usage_date: within_retention,
        credits_used: 100,
      )

    described_class.new.execute({})

    expect(LlmCreditDailyUsage.exists?(usage.id)).to be true
  end

  it "does nothing when discourse_ai is disabled" do
    SiteSetting.discourse_ai_enabled = false

    old_date = 100.days.ago.to_date
    old_usage =
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: old_date, credits_used: 100)

    described_class.new.execute({})

    expect(LlmCreditDailyUsage.exists?(old_usage.id)).to be true
  end
end
