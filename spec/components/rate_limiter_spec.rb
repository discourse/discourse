require 'rails_helper'
require 'rate_limiter'

describe RateLimiter do

  let(:user) { Fabricate(:user) }
  let(:rate_limiter) { RateLimiter.new(user, "peppermint-butler", 2, 60) }

  context 'disabled' do
    before do
      RateLimiter.stubs(:disabled?).returns(true)
      rate_limiter.performed!
      rate_limiter.performed!
    end

    it "returns true for can_perform?" do
      expect(rate_limiter.can_perform?).to eq(true)
    end

    it "doesn't raise an error on performed!" do
      expect { rate_limiter.performed! }.not_to raise_error
    end

  end

  context 'enabled' do
    before do
      RateLimiter.stubs(:disabled?).returns(false)
      rate_limiter.clear!
    end

    context 'never done' do
      it "should perform right away" do
        expect(rate_limiter.can_perform?).to eq(true)
      end

      it "performs without an error" do
        expect { rate_limiter.performed! }.not_to raise_error
      end
    end

    context "remaining" do
      it "updates correctly" do
        expect(rate_limiter.remaining).to eq(2)
        rate_limiter.performed!
        expect(rate_limiter.remaining).to eq(1)
        rate_limiter.performed!
        expect(rate_limiter.remaining).to eq(0)
      end
    end

    context "multiple calls" do
      before do
        rate_limiter.performed!
        rate_limiter.performed!
      end

      it "returns false for can_perform when the limit has been hit" do
        expect(rate_limiter.can_perform?).to eq(false)
        expect(rate_limiter.remaining).to eq(0)
      end

      it "raises an error the third time called" do
        expect { rate_limiter.performed! }.to raise_error(RateLimiter::LimitExceeded)
      end

      context "as an admin/moderator" do
        it "returns true for can_perform if the user is an admin" do
          user.admin = true
          expect(rate_limiter.can_perform?).to eq(true)
          expect(rate_limiter.remaining).to eq(2)
        end

        it "doesn't raise an error when an admin performs the task" do
          user.admin = true
          expect { rate_limiter.performed! }.not_to raise_error
        end

        it "returns true for can_perform if the user is a mod" do
          user.moderator = true
          expect(rate_limiter.can_perform?).to eq(true)
        end

        it "doesn't raise an error when a moderator performs the task" do
          user.moderator = true
          expect { rate_limiter.performed! }.not_to raise_error
        end
      end

      context "rollback!" do
        before do
          rate_limiter.rollback!
        end

        it "returns true for can_perform since there is now room" do
          expect(rate_limiter.can_perform?).to eq(true)
        end

        it "raises no error now that there is room" do
          expect { rate_limiter.performed! }.not_to raise_error
        end
      end

    end
  end

end
