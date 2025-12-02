# frozen_string_literal: true

RSpec.describe LlmCreditDailyUsage do
  fab!(:llm_model)

  describe "validations" do
    it "requires llm_model_id" do
      usage = LlmCreditDailyUsage.new(usage_date: Date.current, credits_used: 100)
      expect(usage).not_to be_valid
      expect(usage.errors[:llm_model_id]).to be_present
    end

    it "requires usage_date" do
      usage = LlmCreditDailyUsage.new(llm_model: llm_model, credits_used: 100)
      expect(usage).not_to be_valid
      expect(usage.errors[:usage_date]).to be_present
    end

    it "requires credits_used to be non-negative" do
      usage =
        LlmCreditDailyUsage.new(llm_model: llm_model, usage_date: Date.current, credits_used: -1)
      expect(usage).not_to be_valid
      expect(usage.errors[:credits_used]).to be_present
    end

    it "enforces unique llm_model_id and usage_date combination" do
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: Date.current, credits_used: 100)

      duplicate =
        LlmCreditDailyUsage.new(llm_model: llm_model, usage_date: Date.current, credits_used: 200)

      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows same date for different models" do
      other_model = Fabricate(:llm_model)

      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: Date.current, credits_used: 100)

      usage =
        LlmCreditDailyUsage.new(llm_model: other_model, usage_date: Date.current, credits_used: 200)

      expect(usage).to be_valid
    end
  end

  describe ".find_or_create_for_today" do
    it "creates a new record for today if none exists" do
      usage = LlmCreditDailyUsage.find_or_create_for_today(llm_model)

      expect(usage).to be_persisted
      expect(usage.llm_model_id).to eq(llm_model.id)
      expect(usage.usage_date).to eq(Date.current)
      expect(usage.credits_used).to eq(0)
    end

    it "returns existing record for today" do
      existing =
        LlmCreditDailyUsage.create!(
          llm_model: llm_model,
          usage_date: Date.current,
          credits_used: 100,
        )

      usage = LlmCreditDailyUsage.find_or_create_for_today(llm_model)

      expect(usage.id).to eq(existing.id)
      expect(usage.credits_used).to eq(100)
    end
  end

  describe ".increment_usage!" do
    it "creates record and increments when none exists" do
      LlmCreditDailyUsage.increment_usage!(llm_model, 50)

      usage = LlmCreditDailyUsage.find_by(llm_model: llm_model, usage_date: Date.current)
      expect(usage.credits_used).to eq(50)
    end

    it "increments existing record" do
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: Date.current, credits_used: 100)

      LlmCreditDailyUsage.increment_usage!(llm_model, 50)

      usage = LlmCreditDailyUsage.find_by(llm_model: llm_model, usage_date: Date.current)
      expect(usage.credits_used).to eq(150)
    end

    it "handles concurrent increments correctly" do
      threads = []
      5.times { threads << Thread.new { LlmCreditDailyUsage.increment_usage!(llm_model, 10) } }
      threads.each(&:join)

      usage = LlmCreditDailyUsage.find_by(llm_model: llm_model, usage_date: Date.current)
      expect(usage.credits_used).to eq(50)
    end
  end

  describe ".usage_for_date" do
    it "returns credits for existing date" do
      LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: Date.current, credits_used: 250)

      expect(LlmCreditDailyUsage.usage_for_date(llm_model, Date.current)).to eq(250)
    end

    it "returns 0 for date with no record" do
      expect(LlmCreditDailyUsage.usage_for_date(llm_model, Date.current)).to eq(0)
    end

    it "returns 0 for different model" do
      other_model = Fabricate(:llm_model)
      LlmCreditDailyUsage.create!(
        llm_model: other_model,
        usage_date: Date.current,
        credits_used: 250,
      )

      expect(LlmCreditDailyUsage.usage_for_date(llm_model, Date.current)).to eq(0)
    end
  end

  describe ".cleanup_old_records!" do
    it "deletes records older than retention period" do
      old_date = 100.days.ago.to_date
      recent_date = 50.days.ago.to_date

      old_usage =
        LlmCreditDailyUsage.create!(llm_model: llm_model, usage_date: old_date, credits_used: 100)

      recent_usage =
        LlmCreditDailyUsage.create!(
          llm_model: llm_model,
          usage_date: recent_date,
          credits_used: 200,
        )

      LlmCreditDailyUsage.cleanup_old_records!(90)

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

      LlmCreditDailyUsage.cleanup_old_records!(90)

      expect(LlmCreditDailyUsage.exists?(usage.id)).to be true
    end

    it "keeps today's record" do
      usage =
        LlmCreditDailyUsage.create!(
          llm_model: llm_model,
          usage_date: Date.current,
          credits_used: 100,
        )

      LlmCreditDailyUsage.cleanup_old_records!(90)

      expect(LlmCreditDailyUsage.exists?(usage.id)).to be true
    end
  end
end
