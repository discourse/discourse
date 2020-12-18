# frozen_string_literal: true

require 'rails_helper'

describe DoNotDisturbController do
  it 'requires you to be logged in' do
    post "/do-not-disturb.json", params: { duration: 30 }
    expect(response.status).to eq(403)
  end

  describe 'logged in' do
    fab!(:user) { Fabricate(:user) }

    before do
      sign_in(user)
    end

    it 'returns a 400 when a duration is not passed in' do
      post "/do-not-disturb.json"
      expect(response.status).to eq(400)
    end

    it 'works properly with integer minute durations' do
      freeze_time
      post "/do-not-disturb.json", params: { duration: 30 }

      expect(response.status).to eq(200)
      expect(user.do_not_disturb_timings.last.ends_at).to eq_time(30.minutes.from_now)
    end

    it 'works properly with integer minute durations' do
      post "/do-not-disturb.json", params: { duration: -30 }
      expect(response.status).to eq(422)
      expect(response.parsed_body).to eq({ "errors" => ["Ends at is invalid"] })
    end

    include ActiveSupport::Testing::TimeHelpers
    it "works properly with duration of 'tomorrow'" do
      travel_to Time.new(2020, 11, 24, 01, 04, 44) do
        post "/do-not-disturb.json", params: { duration: 'tomorrow' }
        expect(response.status).to eq(200)
        expect(user.do_not_disturb_timings.last.ends_at.to_i).to eq(Time.new(2020, 11, 24, 23, 59, 59).utc.to_i)
      end
    end
  end
end
