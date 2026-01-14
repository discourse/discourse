# frozen_string_literal: true

RSpec.describe LlmQuotaUsage do
  fab!(:group)
  fab!(:user)
  fab!(:llm_model)

  fab!(:llm_quota) do
    Fabricate(
      :llm_quota,
      group: group,
      llm_model: llm_model,
      max_tokens: 1000,
      max_usages: 10,
      duration_seconds: 1.day.to_i,
    )
  end

  before { enable_current_plugin }

  describe ".find_or_create_for" do
    it "creates a new usage record if none exists" do
      freeze_time

      usage = described_class.find_or_create_for(user: user, llm_quota: llm_quota)

      expect(usage).to be_persisted
      expect(usage.started_at).to eq_time(Time.current)
      expect(usage.reset_at).to eq_time(Time.current + llm_quota.duration_seconds.seconds)
      expect(usage.input_tokens_used).to eq(0)
      expect(usage.output_tokens_used).to eq(0)
      expect(usage.usages).to eq(0)
    end

    it "returns existing usage record if one exists" do
      existing = Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota)

      usage = described_class.find_or_create_for(user: user, llm_quota: llm_quota)

      expect(usage.id).to eq(existing.id)
    end
  end

  describe "#reset_if_needed!" do
    let(:usage) { Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota) }

    it "resets usage when past reset_at" do
      usage.update!(
        input_tokens_used: 100,
        output_tokens_used: 200,
        usages: 5,
        reset_at: 1.minute.ago,
      )

      freeze_time

      usage.reset_if_needed!

      expect(usage.reload.input_tokens_used).to eq(0)
      expect(usage.output_tokens_used).to eq(0)
      expect(usage.usages).to eq(0)
      expect(usage.started_at).to eq_time(Time.current)
      expect(usage.reset_at).to eq_time(Time.current + llm_quota.duration_seconds.seconds)
    end

    it "doesn't reset if reset_at hasn't passed" do
      freeze_time

      original_values = {
        input_tokens_used: 100,
        output_tokens_used: 200,
        usages: 5,
        reset_at: 1.minute.from_now,
      }

      usage.update!(original_values)
      usage.reset_if_needed!

      usage.reload
      expect(usage.input_tokens_used).to eq(original_values[:input_tokens_used])
      expect(usage.output_tokens_used).to eq(original_values[:output_tokens_used])
      expect(usage.usages).to eq(original_values[:usages])
      expect(usage.reset_at).to eq_time(original_values[:reset_at])
    end
  end

  describe "#increment_usage!" do
    let(:usage) { Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota) }

    it "increments usage counts" do
      usage.increment_usage!(input_tokens: 50, output_tokens: 30)

      expect(usage.reload.input_tokens_used).to eq(50)
      expect(usage.output_tokens_used).to eq(30)
      expect(usage.usages).to eq(1)
    end

    it "accumulates multiple increments" do
      2.times { usage.increment_usage!(input_tokens: 50, output_tokens: 30) }

      expect(usage.reload.input_tokens_used).to eq(100)
      expect(usage.output_tokens_used).to eq(60)
      expect(usage.usages).to eq(2)
    end

    it "resets counts if needed before incrementing" do
      usage.update!(
        input_tokens_used: 100,
        output_tokens_used: 200,
        usages: 5,
        reset_at: 1.minute.ago,
      )

      usage.increment_usage!(input_tokens: 50, output_tokens: 30)

      expect(usage.reload.input_tokens_used).to eq(50)
      expect(usage.output_tokens_used).to eq(30)
      expect(usage.usages).to eq(1)
    end
  end

  describe "#check_quota!" do
    let(:usage) { Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota) }

    it "doesn't raise error when within limits" do
      expect { usage.check_quota! }.not_to raise_error
    end

    it "raises error when max_tokens exceeded" do
      usage.update!(input_tokens_used: llm_quota.max_tokens + 1)

      expect { usage.check_quota! }.to raise_error(LlmQuotaUsage::QuotaExceededError, /exceeded/)
    end

    it "raises error when max_usages exceeded" do
      usage.update!(usages: llm_quota.max_usages + 1)

      expect { usage.check_quota! }.to raise_error(LlmQuotaUsage::QuotaExceededError, /exceeded/)
    end

    it "resets quota if needed before checking" do
      usage.update!(input_tokens_used: llm_quota.max_tokens + 1, reset_at: 1.minute.ago)

      expect { usage.check_quota! }.not_to raise_error
      expect(usage.reload.input_tokens_used).to eq(0)
    end
  end

  describe "#quota_exceeded?" do
    let(:usage) { Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota) }

    it "returns false when within limits" do
      expect(usage.quota_exceeded?).to be false
    end

    it "returns true when max_tokens exceeded" do
      usage.update!(input_tokens_used: llm_quota.max_tokens + 1)
      expect(usage.quota_exceeded?).to be true
    end

    it "returns true when max_usages exceeded" do
      usage.update!(usages: llm_quota.max_usages + 1)
      expect(usage.quota_exceeded?).to be true
    end

    it "returns false when quota is nil" do
      tokens = llm_quota.max_tokens + 1
      usage.llm_quota.update!(max_tokens: nil)
      usage.update!(input_tokens_used: tokens)
      expect(usage.quota_exceeded?).to be false
    end
  end

  describe "calculation methods" do
    let(:usage) { Fabricate(:llm_quota_usage, user: user, llm_quota: llm_quota) }

    describe "#total_tokens_used" do
      it "sums input and output tokens" do
        usage.update!(input_tokens_used: 100, output_tokens_used: 200)
        expect(usage.total_tokens_used).to eq(300)
      end
    end

    describe "#remaining_tokens" do
      it "calculates remaining tokens when under limit" do
        usage.update!(input_tokens_used: 300, output_tokens_used: 200)
        expect(usage.remaining_tokens).to eq(500)
      end

      it "returns 0 when over limit" do
        usage.update!(input_tokens_used: 800, output_tokens_used: 300)
        expect(usage.remaining_tokens).to eq(0)
      end

      it "returns nil when no max_tokens set" do
        usage.llm_quota.update!(max_tokens: nil)
        expect(usage.remaining_tokens).to be_nil
      end
    end

    describe "#remaining_usages" do
      it "calculates remaining usages when under limit" do
        usage.update!(usages: 7)
        expect(usage.remaining_usages).to eq(3)
      end

      it "returns 0 when over limit" do
        usage.update!(usages: 15)
        expect(usage.remaining_usages).to eq(0)
      end

      it "returns nil when no max_usages set" do
        usage.llm_quota.update!(max_usages: nil)
        expect(usage.remaining_usages).to be_nil
      end
    end

    describe "#percentage_tokens_used" do
      it "calculates percentage correctly" do
        usage.update!(input_tokens_used: 250, output_tokens_used: 250)
        expect(usage.percentage_tokens_used).to eq(50)
      end

      it "caps at 100%" do
        usage.update!(input_tokens_used: 2000)
        expect(usage.percentage_tokens_used).to eq(100)
      end

      it "returns 0 when no max_tokens set" do
        usage.llm_quota.update!(max_tokens: nil)
        expect(usage.percentage_tokens_used).to eq(0)
      end
    end

    describe "#percentage_usages_used" do
      it "calculates percentage correctly" do
        usage.update!(usages: 5)
        expect(usage.percentage_usages_used).to eq(50)
      end

      it "caps at 100%" do
        usage.update!(usages: 20)
        expect(usage.percentage_usages_used).to eq(100)
      end

      it "returns 0 when no max_usages set" do
        usage.llm_quota.update!(max_usages: nil)
        expect(usage.percentage_usages_used).to eq(0)
      end
    end
  end
end
