# frozen_string_literal: true

RSpec.describe Sidekiq::Pausable do
  after { Sidekiq.unpause_all! }

  it "can still run heartbeats when paused" do
    Sidekiq.pause!

    freeze_time 1.week.from_now

    jobs = Sidekiq::ScheduledSet.new
    jobs.clear
    middleware = Sidekiq::Pausable.new

    middleware.call(Jobs::RunHeartbeat.new, { "args" => [{}] }, "critical") { "done" }

    jobs = Sidekiq::ScheduledSet.new
    expect(jobs.size).to eq(0)
  end
end
