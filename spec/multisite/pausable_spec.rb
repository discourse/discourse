# frozen_string_literal: true

require "rails_helper"

RSpec.describe Sidekiq::Pausable do
  after do
    Sidekiq.unpause_all!
  end

  it "can still run heartbeats when paused" do
    Sidekiq.pause!

    freeze_time 1.week.from_now

    jobs = Sidekiq::ScheduledSet.new
    jobs.clear
    middleware = Sidekiq::Pausable.new

    middleware.call(Jobs::RunHeartbeat.new, { "args" => [{}] }, "critical") do
      "done"
    end

    jobs = Sidekiq::ScheduledSet.new
    expect(jobs.size).to eq(0)
  end
end
