# encoding: utf-8
require 'rails_helper'
require 'scheduler/scheduler'

describe Scheduler::ScheduleInfo do

  let(:manager) { Scheduler::Manager.new }

  context "every" do
    class RandomJob
      extend ::Scheduler::Schedule

      every 1.hour

      def perform
        # work_it
      end
    end

    before do
      @info = manager.schedule_info(RandomJob)
      @info.del!
    end

    after do
      manager.stop!
      $redis.del manager.class.queue_key
    end

    it "is a scheduled job" do
      expect(RandomJob).to be_scheduled
    end

    it 'starts off invalid' do
      expect(@info.valid?).to eq(false)
    end

    it 'will have a due date in the next 5 minutes if it was blank' do
      @info.schedule!
      expect(@info.valid?).to eq(true)
      expect(@info.next_run).to be_within(5.minutes).of(Time.now.to_i)
    end

    it 'will have a due date within the next hour if it just ran' do
      @info.prev_run = Time.now.to_i
      @info.schedule!
      expect(@info.valid?).to eq(true)
      expect(@info.next_run).to be_within(1.hour * manager.random_ratio).of(Time.now.to_i + 1.hour)
    end

    it 'is invalid if way in the future' do
      @info.next_run = Time.now.to_i + 1.year
      expect(@info.valid?).to eq(false)
    end
  end

  context "daily" do

    class DailyJob
      extend ::Scheduler::Schedule
      daily at: 11.hours

      def perform
      end
    end

    before do
      freeze_time Time.parse("2010-01-10 10:00:00")

      @info = manager.schedule_info(DailyJob)
      @info.del!
    end

    after do
      manager.stop!
      $redis.del manager.class.queue_key
    end

    it "is a scheduled job" do
      expect(DailyJob).to be_scheduled
    end

    it "starts off invalid" do
      expect(@info.valid?).to eq(false)
    end

    it "will have a due date at the appropriate time if blank" do
      expect(@info.next_run).to eq(nil)
      @info.schedule!

      expect(JSON.parse($redis.get(@info.key))["next_run"])
        .to eq((Time.zone.now.midnight + 11.hours).to_i)

      expect(@info.valid?).to eq(true)
    end

    it 'is invalid if way in the future' do
      @info.next_run = Time.now.to_i + 1.year
      expect(@info.valid?).to eq(false)
    end
  end

end
