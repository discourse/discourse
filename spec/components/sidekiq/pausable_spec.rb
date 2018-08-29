require 'rails_helper'
require_dependency 'sidekiq/pausable'

describe Sidekiq do
  after do
    Sidekiq.unpause!
  end

  it "can pause and unpause" do
    Sidekiq.pause!
    expect(Sidekiq.paused?).to eq(true)
    Sidekiq.unpause!
    expect(Sidekiq.paused?).to eq(false)
  end

  it "can still run heartbeats when paused" do
    Sidekiq.pause!

    freeze_time 1.week.from_now

    jobs = Sidekiq::ScheduledSet.new

    Sidekiq::Testing.disable! do
      jobs.clear

      middleware = Sidekiq::Pausable.new
      middleware.call(Jobs::RunHeartbeat.new, { "args" => [{}] }, "critical") do
        "done"
      end

      jobs = Sidekiq::ScheduledSet.new
      expect(jobs.size).to eq(0)
    end

  end
end
