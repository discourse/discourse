require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::Heartbeat do
  after do
    Discourse.disable_readonly_mode
  end

  it "still enqueues heartbeats in readonly mode" do
    freeze_time 1.week.from_now

    Discourse.enable_readonly_mode

    Sidekiq::Testing.inline! do
      Jobs::Heartbeat.new.perform(nil)
      expect(Jobs::RunHeartbeat.last_heartbeat).to eq(Time.new.to_i)
    end
  end
end
