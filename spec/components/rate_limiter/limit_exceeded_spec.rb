require 'rails_helper'

RSpec.describe RateLimiter::LimitExceeded do
  describe '#description' do
    it 'should return the right description' do
      [
        [3, I18n.t("rate_limiter.short_time")],
        [59, I18n.t("rate_limiter.seconds", count: 59)],
        [3599, I18n.t("rate_limiter.minutes", count: 59)],
        [7000, I18n.t("rate_limiter.hours", count: 1)]
      ].each do |available_in, time_left|

        expect(described_class.new(available_in).description).to eq(I18n.t(
          "rate_limiter.too_many_requests",
          time_left: time_left
        ))
      end
    end
  end
end
