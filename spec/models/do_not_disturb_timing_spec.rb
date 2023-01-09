# frozen_string_literal: true

RSpec.describe DoNotDisturbTiming do
  fab!(:user) { Fabricate(:user) }

  describe "validations" do
    it "is invalid when ends_at is before starts_at" do
      freeze_time
      timing = DoNotDisturbTiming.new(user: user, starts_at: Time.zone.now, ends_at: 1.hour.ago)
      timing.valid?
      expect(timing.errors[:ends_at]).to be_present
    end
  end
end
