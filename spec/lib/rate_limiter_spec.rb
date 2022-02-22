# frozen_string_literal: true

require 'rails_helper'
require 'rate_limiter'

describe RateLimiter do

  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }
  let(:rate_limiter) { RateLimiter.new(user, "peppermint-butler", 2, 60) }
  let(:apply_staff_rate_limiter) { RateLimiter.new(admin, "peppermint-servant", 5, 40, apply_limit_to_staff: true) }
  let(:staff_rate_limiter) { RateLimiter.new(user, "peppermind-servant", 5, 40, staff_limit: { max: 10, secs: 80 }) }
  let(:admin_staff_rate_limiter) { RateLimiter.new(admin, "peppermind-servant", 5, 40, staff_limit: { max: 10, secs: 80 }) }

  context 'disabled' do
    before do
      rate_limiter.performed!
      rate_limiter.performed!
    end

    it "should be disabled" do
      expect(RateLimiter.disabled?).to eq(true)
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
      RateLimiter.enable
      rate_limiter.clear!
      staff_rate_limiter.clear!
      admin_staff_rate_limiter.clear!
    end

    context 'aggressive rate limiter' do

      it 'can operate correctly and totally stop limiting' do

        freeze_time

        # 2 requests every 30 seconds
        limiter = RateLimiter.new(nil, "test", 2, 30, global: true, aggressive: true)
        limiter.clear!

        limiter.performed!
        limiter.performed!
        freeze_time 29.seconds.from_now

        expect do
          limiter.performed!
        end.to raise_error(RateLimiter::LimitExceeded)

        expect do
          limiter.performed!
        end.to raise_error(RateLimiter::LimitExceeded)

        # in aggressive mode both these ^^^ count as an attempt
        freeze_time 29.seconds.from_now

        expect do
          limiter.performed!
        end.to raise_error(RateLimiter::LimitExceeded)

        expect do
          limiter.performed!
        end.to raise_error(RateLimiter::LimitExceeded)

        freeze_time 30.seconds.from_now

        expect { limiter.performed! }.not_to raise_error
        expect { limiter.performed! }.not_to raise_error

      end
    end

    context 'global rate limiter' do

      it 'can operate in global mode' do
        limiter = RateLimiter.new(nil, "test", 2, 30, global: true)
        limiter.clear!

        thrown = false

        limiter.performed!
        limiter.performed!
        begin
          limiter.performed!
        rescue RateLimiter::LimitExceeded => e
          expect(Integer === e.available_in).to eq(true)
          expect(e.available_in).to be > 28
          expect(e.available_in).to be < 32
          thrown = true
        end
        expect(thrown).to be(true)
      end

    end

    context 'handles readonly' do
      before do
        Discourse.redis.without_namespace.slaveof '10.0.0.1', '99999'
      end

      after do
        Discourse.redis.without_namespace.slaveof 'no', 'one'
      end

      it 'does not explode' do
        expect { rate_limiter.performed! }.not_to raise_error
      end
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

    context 'max is less than or equal to zero' do

      it 'should raise the right error' do
        [-1, 0, nil].each do |max|
          expect do
            RateLimiter.new(user, "a", max, 60).performed!
          end.to raise_error(RateLimiter::LimitExceeded)
        end
      end
    end

    context "multiple calls" do
      before do
        freeze_time
        rate_limiter.performed!
        rate_limiter.performed!
      end

      it "returns false for can_perform when the limit has been hit" do
        expect(rate_limiter.can_perform?).to eq(false)
        expect(rate_limiter.remaining).to eq(0)
      end

      it "raises an error the third time called" do
        expect { rate_limiter.performed! }.to raise_error do |error|
          expect(error).to be_a(RateLimiter::LimitExceeded)
          expect(error).to having_attributes(available_in: 60)
        end
      end

      it 'raises no error when the sliding window ended' do
        freeze_time 60.seconds.from_now
        expect { rate_limiter.performed! }.not_to raise_error
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

        it "applies max / secs to staff when apply_limit_to_staff flag is true" do
          5.times { apply_staff_rate_limiter.performed! }
          freeze_time 10.seconds.from_now
          expect { apply_staff_rate_limiter.performed! }.to raise_error do |error|
            expect(error).to be_a(RateLimiter::LimitExceeded)
            expect(error).to having_attributes(available_in: 30)
          end
        end

        it "applies staff_limit max when present for staff" do
          expect(admin_staff_rate_limiter.can_perform?).to eq(true)
          expect(admin_staff_rate_limiter.remaining).to eq(10)
        end

        it "applies staff_limit secs when present for staff" do
          10.times { admin_staff_rate_limiter.performed! }
          freeze_time 10.seconds.from_now
          expect { admin_staff_rate_limiter.performed! }.to raise_error do |error|
            expect(error).to be_a(RateLimiter::LimitExceeded)
            expect(error).to having_attributes(available_in: 70)
          end
        end

        it "applies standard max to non-staff users when staff_limit values are present" do
          expect(staff_rate_limiter.can_perform?).to eq(true)
          expect(staff_rate_limiter.remaining).to eq(5)
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
