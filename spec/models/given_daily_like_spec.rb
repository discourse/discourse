# frozen_string_literal: true

require 'rails_helper'

describe GivenDailyLike do

  it 'no errors without a user' do
    expect(-> { GivenDailyLike.increment_for(nil) }).not_to raise_error
    expect(-> { GivenDailyLike.decrement_for(nil) }).not_to raise_error
  end

  context 'with a user' do
    fab!(:user) { Fabricate(:user) }

    def value_for(user_id, date)
      GivenDailyLike.find_for(user_id, date).pluck(:likes_given)[0] || 0
    end

    def limit_reached_for(user_id, date)
      GivenDailyLike.find_for(user_id, date).pluck(:limit_reached)[0] || false
    end

    it 'can be incremented and decremented' do
      SiteSetting.max_likes_per_day = 2

      dt = Date.today
      freeze_time dt

      expect(value_for(user.id, dt)).to eq(0)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.increment_for(user.id)
      expect(value_for(user.id, dt)).to eq(1)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.increment_for(user.id)
      expect(value_for(user.id, dt)).to eq(2)
      expect(limit_reached_for(user.id, dt)).to eq(true)

      GivenDailyLike.decrement_for(user.id)
      expect(value_for(user.id, dt)).to eq(1)
      expect(limit_reached_for(user.id, dt)).to eq(false)

      GivenDailyLike.decrement_for(user.id)
      expect(value_for(user.id, dt)).to eq(0)
      expect(limit_reached_for(user.id, dt)).to eq(false)
    end

  end

end
