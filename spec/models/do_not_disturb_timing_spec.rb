# frozen_string_literal: true

require 'rails_helper'

describe DoNotDisturbTiming do
  fab!(:user) { Fabricate(:user) }

  describe "validations" do
    it 'is invalid when ends_at is before starts_at' do
      freeze_time
      timing = DoNotDisturbTiming.new(user: user, starts_at: Time.current, ends_at: Time.current - 1.hour)
      timing.valid?
      expect(timing.errors).to be_empty
    end
  end
end
