# frozen_string_literal: true

RSpec.describe DecisionModelCreditDailyUsage do
  fab!(:decision_model) { Fabricate(:decision_model, id: -1) }

  before { enable_current_plugin }

  def usage(date = Date.current)
    described_class.usage_for_date(decision_model.id, date)
  end

  def persisted_usage(date = Date.current)
    described_class.where(decision_model:, usage_date: date).pick(:credits_used)
  end

  def lose_redis_total(date = Date.current)
    Discourse.redis.del("discourse_ai:decision_model_credits:total:#{decision_model.id}:#{date}")
  end

  describe ".increment_usage!" do
    it "keeps the running total in Redis without writing a row, scheduling one flush" do
      expect_enqueued_with(job: :flush_decision_model_credit_usage) do
        described_class.increment_usage!(decision_model, 100)
      end
      described_class.increment_usage!(decision_model, 50)

      expect(usage).to eq(150)
      expect(persisted_usage).to be_nil
      expect(
        Discourse.redis.ttl(
          "discourse_ai:decision_model_credits:total:#{decision_model.id}:#{Date.current}",
        ),
      ).to be_within(60).of(described_class::TOTAL_TTL.to_i)
      expect(Jobs::FlushDecisionModelCreditUsage.jobs.size).to eq(1)
    end

    it "continues from the persisted row when the Redis total is lost" do
      described_class.increment_usage!(decision_model, 100)
      described_class.flush_pending!
      lose_redis_total

      described_class.increment_usage!(decision_model, 10)

      expect(usage).to eq(110)
    end
  end

  describe ".usage_for_date" do
    it "restarts from the persisted row when the Redis total is lost" do
      described_class.create!(decision_model:, usage_date: Date.current, credits_used: 40)

      expect(usage).to eq(40)
    end

    it "stays accurate across a flush inside a query-cached job" do
      described_class.increment_usage!(decision_model, 100)

      ActiveRecord::Base.cache do
        expect(usage).to eq(100)
        described_class.flush_pending!
        lose_redis_total
        expect(usage).to eq(100)
      end
    end
  end

  describe ".flush_pending!" do
    it "copies the day's total into its row, so repeated flushes are harmless" do
      described_class.increment_usage!(decision_model, 100)
      Jobs::FlushDecisionModelCreditUsage.new.execute({})
      described_class.flush_pending!

      described_class.increment_usage!(decision_model, 25)
      described_class.flush_pending!

      expect(persisted_usage).to eq(125)
      expect(usage).to eq(125)
    end

    it "never lowers recorded usage when a lost total is reseeded below it" do
      described_class.increment_usage!(decision_model, 100)
      described_class.flush_pending!
      DB.exec(
        "UPDATE decision_model_credit_daily_usages SET credits_used = 500 WHERE decision_model_id = ?",
        decision_model.id,
      )
      described_class.increment_usage!(decision_model, 10)

      described_class.flush_pending!

      expect(persisted_usage).to eq(500)
    end

    it "persists usage recorded before midnight to that day" do
      freeze_time(Time.utc(2026, 10, 15, 23, 59))
      described_class.increment_usage!(decision_model, 100)

      freeze_time(Time.utc(2026, 10, 16, 0, 1))
      described_class.flush_pending!

      expect(persisted_usage(Date.new(2026, 10, 15))).to eq(100)
      expect(usage).to eq(0)
    end

    it "skips deleted models" do
      described_class.increment_usage!(decision_model, 100)
      decision_model.destroy!

      described_class.flush_pending!

      expect(described_class.count).to eq(0)
    end

    it "flushes again later when the database write fails" do
      described_class.increment_usage!(decision_model, 100)
      DB.stubs(:exec).raises(PG::ConnectionBad)

      expect { described_class.flush_pending! }.to raise_error(PG::ConnectionBad)

      DB.unstub(:exec)
      described_class.flush_pending!
      expect(persisted_usage).to eq(100)
    end
  end
end
