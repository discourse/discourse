# encoding: utf-8
require 'rails_helper'
require 'scheduler/scheduler'

describe Scheduler::Manager do

  module Testing
    class RandomJob
      extend ::Scheduler::Schedule

      def self.runs=(val)
        @runs = val
      end

      def self.runs
        @runs ||= 0
      end

      every 5.minutes

      def perform
        self.class.runs+=1
        sleep 0.001
      end
    end

    class SuperLongJob
      extend ::Scheduler::Schedule

      every 10.minutes

      def perform
        sleep 1000
      end
    end

    class PerHostJob
      extend ::Scheduler::Schedule

      per_host
      every 10.minutes

      def self.runs=(val)
        @runs = val
      end

      def self.runs
        @runs ||= 0
      end

      def perform
        self.class.runs += 1
      end
    end
  end

  let(:manager) {
    Scheduler::Manager.new(DiscourseRedis.new, enable_stats: false)
  }

  before {
    expect(ActiveRecord::Base.connection_pool.connections.length).to eq(1)
  }

  after {
    expect(ActiveRecord::Base.connection_pool.connections.length).to eq(1)
  }

  it 'can disable stats' do
    manager = Scheduler::Manager.new(DiscourseRedis.new, enable_stats: false)
    expect(manager.enable_stats).to eq(false)

    manager = Scheduler::Manager.new(DiscourseRedis.new)
    expect(manager.enable_stats).to eq(true)
  end

  before do
    $redis.del manager.class.lock_key
    $redis.del manager.class.queue_key
    manager.remove(Testing::RandomJob)
    manager.remove(Testing::SuperLongJob)
    manager.remove(Testing::PerHostJob)
  end

  after do
    manager.stop!
    manager.remove(Testing::RandomJob)
    manager.remove(Testing::SuperLongJob)
    manager.remove(Testing::PerHostJob)
  end

  describe 'per host jobs' do
    it "correctly schedules on multiple hosts" do
      Testing::PerHostJob.runs = 0

      hosts = ['a','b','c']

      hosts.map do |host|

        manager = Scheduler::Manager.new(DiscourseRedis.new, hostname: host, enable_stats: false)
        manager.ensure_schedule!(Testing::PerHostJob)

        info = manager.schedule_info(Testing::PerHostJob)
        info.next_run = Time.now.to_i - 1
        info.write!

        manager

      end.each do |manager|

        manager.blocking_tick
        manager.stop!

      end

      expect(Testing::PerHostJob.runs).to eq(3)

    end
  end

  describe '#sync' do

    it 'increases' do
      expect(Scheduler::Manager.seq).to eq(Scheduler::Manager.seq - 1)
    end
  end

  describe '#tick' do

    it 'should nuke missing jobs' do
      $redis.zadd Scheduler::Manager.queue_key, Time.now.to_i - 1000, "BLABLA"
      manager.tick
      expect($redis.zcard(Scheduler::Manager.queue_key)).to eq(0)
    end

    it 'should recover from crashed manager' do

      info = manager.schedule_info(Testing::SuperLongJob)
      info.next_run = Time.now.to_i - 1
      info.write!

      manager.tick
      manager.stop!

      $redis.del manager.identity_key

      manager = Scheduler::Manager.new(DiscourseRedis.new, enable_stats: false)
      manager.reschedule_orphans!

      info = manager.schedule_info(Testing::SuperLongJob)
      expect(info.next_run).to be <= Time.now.to_i
    end

    # something about logging jobs causing a leak in connection pool in test
    # it 'should log when job finishes running' do
    #
    #   Testing::RandomJob.runs = 0
    #
    #   info = manager.schedule_info(Testing::RandomJob)
    #   info.next_run = Time.now.to_i - 1
    #   info.write!
    #
    #   # with stats so we must be careful to cleanup
    #   manager = Scheduler::Manager.new(DiscourseRedis.new)
    #   manager.blocking_tick
    #   manager.stop!
    #
    #   stat = SchedulerStat.first
    #   expect(stat).to be_present
    #   expect(stat.duration_ms).to be > 0
    #   expect(stat.success).to be true
    #   SchedulerStat.destroy_all
    # end

    it 'should only run pending job once' do

      Testing::RandomJob.runs = 0

      info = manager.schedule_info(Testing::RandomJob)
      info.next_run = Time.now.to_i - 1
      info.write!

      (0..5).map do
        Thread.new do
          manager = Scheduler::Manager.new(DiscourseRedis.new, enable_stats: false)
          manager.blocking_tick
          manager.stop!
        end
      end.map(&:join)

      expect(Testing::RandomJob.runs).to eq(1)

      info = manager.schedule_info(Testing::RandomJob)
      expect(info.prev_run).to be <= Time.now.to_i
      expect(info.prev_duration).to be > 0
      expect(info.prev_result).to eq("OK")
    end

  end

  describe '#discover_schedules' do
    it 'Discovers Testing::RandomJob' do
      expect(Scheduler::Manager.discover_schedules).to include(Testing::RandomJob)
    end
  end

  describe '#next_run' do
    it 'should be within the next 5 mins if it never ran' do

      manager.remove(Testing::RandomJob)
      manager.ensure_schedule!(Testing::RandomJob)

      expect(manager.next_run(Testing::RandomJob))
        .to be_within(5.minutes.to_i).of(Time.now.to_i + 5.minutes)
    end
  end
end
