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

    queue = Demon::Sidekiq.create_heartbeat_queue(456451)
    Demon::Sidekiq.stubs(:alive?).returns(true)
    Jobs::Heartbeat.new.perform(nil)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(queue)).to eq(Time.new.to_i)
  end

  it "enqueues heartbeats for all alive workers" do
    freeze_time 1.week.from_now
    Demon::Sidekiq.clear_heartbeat_queues!
    Jobs.run_immediately!

    pid1 = 54545
    pid2 = 78463
    dead_pid = 34642
    worker1_queue = Demon::Sidekiq.create_heartbeat_queue(pid1)
    worker2_queue = Demon::Sidekiq.create_heartbeat_queue(pid2)
    dead_worker_queue = Demon::Sidekiq.create_heartbeat_queue(dead_pid)

    Demon::Sidekiq.stubs(:alive?).with(pid1).returns(true)
    Demon::Sidekiq.stubs(:alive?).with(pid2).returns(true)
    Demon::Sidekiq.stubs(:alive?).with(dead_pid).returns(false)
    Jobs::Heartbeat.new.perform(nil)

    expect(Demon::Sidekiq.get_queue_last_heartbeat(worker1_queue)).to eq(Time.new.to_i)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(worker2_queue)).to eq(Time.new.to_i)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(dead_pid)).to eq(0)
  end

  it "doesn't enqueue hearbeats for workers that have died" do
    freeze_time 1.week.from_now
    Demon::Sidekiq.clear_heartbeat_queues!
    Jobs.run_immediately!

    pid = 56443
    queue = Demon::Sidekiq.create_heartbeat_queue(pid)
    Demon::Sidekiq.stubs(:alive?).with(pid).returns(true)

    Jobs::Heartbeat.new.perform(nil)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(queue)).to eq(Time.new.to_i)

    Demon::Sidekiq.stubs(:alive?).with(pid).returns(false)
    Jobs::Heartbeat.new.perform(nil)
    expect(Demon::Sidekiq.get_queue_last_heartbeat(queue)).to eq(0)
  end
end
