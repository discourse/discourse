# encoding: utf-8
require 'spec_helper'
require 'scheduler/scheduler'

describe Scheduler::ScheduleInfo do

  class RandomJob
    extend ::Scheduler::Schedule

    every 1.hour

    def perform
      # work_it
    end
  end

  let(:manager){ Scheduler::Manager.new }

  before do
    @info = manager.schedule_info(RandomJob)
    @info.del!
    $redis.del manager.class.queue_key
  end

  after do
    manager.stop!
  end

  it 'starts off invalid' do
    @info.valid?.should be_false
  end

  it 'will have a due date in the next 5 minutes if it was blank' do
    @info.schedule!
    @info.valid?.should be_true
    @info.next_run.should be_within(5.minutes).of(Time.now.to_i)
  end

  it 'will have a due date within the next hour if it just ran' do
    @info.prev_run = Time.now.to_i
    @info.schedule!
    @info.valid?.should be_true
    @info.next_run.should be_within(1.hour * manager.random_ratio).of(Time.now.to_i + 1.hour)
  end

  it 'is invalid if way in the future' do
    @info.next_run = Time.now.to_i + 1.year
    @info.valid?.should be_false
  end

end
