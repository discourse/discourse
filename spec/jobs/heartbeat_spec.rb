# frozen_string_literal: true

require 'rails_helper'
require_dependency 'jobs/base'
require_dependency 'demon/sidekiq'

describe Jobs::Heartbeat do
  after do
    Discourse.disable_readonly_mode
  end

  it "still enqueues heartbeats in readonly mode" do
    freeze_time 1.week.from_now
    Demon::Sidekiq.clear_heartbeat_queues!
    Jobs.run_immediately!

    Discourse.enable_readonly_mode

    queue = SecureRandom.hex
    Demon::Sidekiq::QUEUE_IDS << queue
    Jobs::Heartbeat.new.perform(nil)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(queue)).to eq(Time.new.to_i)
  end
end
