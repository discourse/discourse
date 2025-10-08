# frozen_string_literal: true

RSpec.describe LlmCreditAllocation do
  fab!(:seeded_model)
  fab!(:llm_model)

  describe "validations" do
    it "requires llm_model_id" do
      allocation = LlmCreditAllocation.new(monthly_credits: 1000)
      expect(allocation).not_to be_valid
      expect(allocation.errors[:llm_model_id]).to be_present
    end

    it "requires unique llm_model_id" do
      Fabricate(:llm_credit_allocation, llm_model: llm_model)
      allocation = LlmCreditAllocation.new(llm_model: llm_model, monthly_credits: 1000)
      expect(allocation).not_to be_valid
      expect(allocation.errors[:llm_model_id]).to be_present
    end

    it "requires monthly_credits to be positive" do
      allocation = LlmCreditAllocation.new(llm_model: llm_model, monthly_credits: 0)
      expect(allocation).not_to be_valid
      expect(allocation.errors[:monthly_credits]).to be_present
    end

    it "requires soft_limit_percentage between 0 and 100" do
      allocation = LlmCreditAllocation.new(llm_model: llm_model, monthly_credits: 1000)
      allocation.soft_limit_percentage = 101
      expect(allocation).not_to be_valid

      allocation.soft_limit_percentage = -1
      expect(allocation).not_to be_valid

      allocation.soft_limit_percentage = 80
      expect(allocation).to be_valid
    end

    it "sets last_reset_at on create" do
      allocation = Fabricate.build(:llm_credit_allocation, llm_model: llm_model)
      allocation.last_reset_at = nil
      allocation.save!
      expect(allocation.last_reset_at).to be_present
    end
  end

  describe "#credits_remaining" do
    it "returns remaining credits" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 300)
      expect(allocation.credits_remaining).to eq(700)
    end

    it "returns 0 when credits are exhausted" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1200)
      expect(allocation.credits_remaining).to eq(0)
    end
  end

  describe "#percentage_used" do
    it "calculates percentage correctly" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 250)
      expect(allocation.percentage_used).to eq(25.0)
    end

    it "caps at 100%" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1500)
      expect(allocation.percentage_used).to eq(100.0)
    end

    it "returns 0 when monthly_credits is 0" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 0)
      allocation.monthly_credits = 0
      expect(allocation.percentage_used).to eq(0)
    end
  end

  describe "#percentage_remaining" do
    it "calculates percentage correctly" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 250)
      expect(allocation.percentage_remaining).to eq(75.0)
    end

    it "floors at 0%" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1500)
      expect(allocation.percentage_remaining).to eq(0.0)
    end

    it "returns 100.0 when monthly_credits is 0" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 0)
      allocation.monthly_credits = 0
      expect(allocation.percentage_remaining).to eq(100.0)
    end

    it "returns 100.0 when no credits used" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 0)
      expect(allocation.percentage_remaining).to eq(100.0)
    end
  end

  describe "#soft_limit_remaining_reached?" do
    it "returns true when percentage remaining equals (100 - soft_limit)" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 800,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_remaining_reached?).to be true
    end

    it "returns true when percentage remaining is below (100 - soft_limit)" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 900,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_remaining_reached?).to be true
    end

    it "returns false when percentage remaining is above (100 - soft_limit)" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 700,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_remaining_reached?).to be false
    end
  end

  describe "#hard_limit_remaining_reached?" do
    it "returns true when credits_remaining is 0" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1000)
      expect(allocation.hard_limit_remaining_reached?).to be true
    end

    it "returns true when credits_remaining is negative" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1200)
      expect(allocation.hard_limit_remaining_reached?).to be true
    end

    it "returns false when credits_remaining is positive" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 999)
      expect(allocation.hard_limit_remaining_reached?).to be false
    end
  end

  describe "#credits_available?" do
    it "returns true when credits are available" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 500)
      expect(allocation.credits_available?).to be true
    end

    it "returns false when hard limit is reached" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1000)
      expect(allocation.credits_available?).to be false
    end

    it "returns false when hard limit is exceeded" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1100)
      expect(allocation.credits_available?).to be false
    end
  end

  describe "#soft_limit_reached?" do
    it "returns true when percentage equals soft limit" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 800,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_reached?).to be true
    end

    it "returns true when percentage exceeds soft limit" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 900,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_reached?).to be true
    end

    it "returns false when below soft limit" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 700,
          soft_limit_percentage: 80,
        )
      expect(allocation.soft_limit_reached?).to be false
    end
  end

  describe "#hard_limit_reached?" do
    it "returns true when monthly_used equals monthly_credits" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1000)
      expect(allocation.hard_limit_reached?).to be true
    end

    it "returns true when monthly_used exceeds monthly_credits" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1200)
      expect(allocation.hard_limit_reached?).to be true
    end

    it "returns false when below limit" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 999)
      expect(allocation.hard_limit_reached?).to be false
    end
  end

  describe "#next_reset_at" do
    it "returns one month after last_reset_at" do
      freeze_time
      allocation = Fabricate(:llm_credit_allocation, last_reset_at: Time.current)
      expect(allocation.next_reset_at).to eq_time(1.month.from_now)
    end
  end

  describe "#should_reset?" do
    it "returns true when time has passed next_reset_at" do
      allocation = Fabricate(:llm_credit_allocation, last_reset_at: 2.months.ago)
      expect(allocation.should_reset?).to be true
    end

    it "returns false when before next_reset_at" do
      allocation = Fabricate(:llm_credit_allocation, last_reset_at: 1.day.ago)
      expect(allocation.should_reset?).to be false
    end
  end

  describe "#reset_if_needed!" do
    it "resets credits when time has passed" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 800,
          last_reset_at: 2.months.ago,
        )

      freeze_time do
        allocation.reset_if_needed!

        allocation.reload
        expect(allocation.monthly_used).to eq(0)
        expect(allocation.last_reset_at).to be_within(1.second).of(Time.current)
      end
    end

    it "does not reset when time has not passed" do
      original_time = 1.day.ago
      allocation =
        Fabricate(
          :llm_credit_allocation,
          monthly_credits: 1000,
          monthly_used: 800,
          last_reset_at: original_time,
        )

      allocation.reset_if_needed!

      allocation.reload
      expect(allocation.monthly_used).to eq(800)
      expect(allocation.last_reset_at).to be_within(1.second).of(original_time)
    end
  end

  describe "#deduct_credits!" do
    it "increments monthly_used" do
      allocation = Fabricate(:llm_credit_allocation, monthly_used: 100)

      allocation.deduct_credits!(50)

      allocation.reload
      expect(allocation.monthly_used).to eq(150)
    end
  end

  describe "#check_credits!" do
    it "raises error when hard limit reached" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1000)

      expect { allocation.check_credits! }.to raise_error(LlmCreditAllocation::CreditLimitExceeded)
    end

    it "does not raise error when below limit" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 500)

      expect { allocation.check_credits! }.not_to raise_error
    end

    it "attaches allocation to raised exception" do
      allocation = Fabricate(:llm_credit_allocation, monthly_credits: 1000, monthly_used: 1000)

      begin
        allocation.check_credits!
        fail "Expected exception to be raised"
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        expect(e.allocation).to eq(allocation)
      end
    end
  end

  describe ".credits_available?" do
    fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

    it "returns true when model has no credit system" do
      regular_model = Fabricate(:llm_model)
      expect(LlmCreditAllocation.credits_available?(regular_model)).to be true
    end

    it "returns true when model is nil" do
      expect(LlmCreditAllocation.credits_available?(nil)).to be true
    end

    it "returns true when model has no allocation" do
      expect(LlmCreditAllocation.credits_available?(llm_model)).to be true
    end

    it "returns true when credits are available" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 500,
      )
      expect(LlmCreditAllocation.credits_available?(llm_model)).to be true
    end

    it "returns false when hard limit reached" do
      Fabricate(
        :llm_credit_allocation,
        llm_model: llm_model,
        monthly_credits: 1000,
        monthly_used: 1000,
      )
      expect(LlmCreditAllocation.credits_available?(llm_model)).to be false
    end

    it "resets and returns true when reset is needed" do
      allocation =
        Fabricate(
          :llm_credit_allocation,
          llm_model: llm_model,
          monthly_credits: 1000,
          monthly_used: 1000,
          last_reset_at: 2.months.ago,
        )

      freeze_time do
        result = LlmCreditAllocation.credits_available?(llm_model)

        allocation.reload
        expect(result).to be true
        expect(allocation.monthly_used).to eq(0)
      end
    end
  end

  describe "#formatted_reset_time" do
    it "returns formatted reset time" do
      freeze_time do
        allocation = Fabricate(:llm_credit_allocation, last_reset_at: Time.current)
        formatted = allocation.formatted_reset_time

        expect(formatted).to match(/\d{1,2}:\d{2}[ap]m on \w+ \d{1,2}, \d{4}/)
      end
    end

    it "returns empty string when next_reset_at is nil" do
      allocation = Fabricate(:llm_credit_allocation)
      allocation.stubs(:next_reset_at).returns(nil)

      expect(allocation.formatted_reset_time).to eq("")
    end
  end

  describe "#relative_reset_time" do
    it "returns relative time until reset" do
      freeze_time do
        allocation = Fabricate(:llm_credit_allocation, last_reset_at: Time.current)
        relative = allocation.relative_reset_time

        expect(relative).to match(/in .+/)
      end
    end

    it "returns empty string when next_reset_at is nil" do
      allocation = Fabricate(:llm_credit_allocation)
      allocation.stubs(:next_reset_at).returns(nil)

      expect(allocation.relative_reset_time).to eq("")
    end
  end
end
