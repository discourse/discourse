# frozen_string_literal: true

require "pitchfork"
require "pitchfork/configurator"

RSpec.describe Pitchfork::Configurator do
  describe "#[]" do
    it "configures before_worker_exit to finish pool tasks and their deferred jobs" do
      original_async = Scheduler::Defer.async
      Scheduler::Defer.async = true
      completed = Queue.new
      pool = Scheduler::ThreadPool.new(min_threads: 0, max_threads: 1)
      configuration =
        Pitchfork::Configurator.new(config_file: Rails.root.join("config/pitchfork.conf.rb").to_s)
      Discourse.before_fork
      Scheduler::Defer.later { completed << :deferred }
      pool.post do
        Scheduler::Defer.later { completed << :deferred_from_pool }
        completed << :pool
      end

      configuration[:before_worker_exit].call(nil, nil)

      expect(3.times.map { completed.pop(timeout: 0.1) }).to contain_exactly(
        :deferred,
        :pool,
        :deferred_from_pool,
      )
    ensure
      Discourse.resume_after_fork
      pool&.shutdown
      pool&.wait_for_termination(timeout: 5)
      Scheduler::Defer.stop!(finish_work: true)
      Scheduler::Defer.async = original_async
    end
  end
end
