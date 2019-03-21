# encoding: utf-8
require 'rails_helper'
require_dependency 'scheduler/defer'

describe Scheduler::Defer do
  class DeferInstance
    include Scheduler::Deferrable
  end

  def wait_for(timeout, &blk)
    till = Time.now + (timeout.to_f / 1000)
    sleep 0.001 while Time.now < till && !blk.call
  end

  class TrackingLogger < ::Logger
    attr_reader :messages
    def initialize
      super(nil)
      @messages = []
    end
    def add(*args, &block)
      @messages << args
    end
  end

  def track_log_messages
    old_logger = Rails.logger
    logger = Rails.logger = TrackingLogger.new
    yield logger.messages
    logger.messages
  ensure
    Rails.logger = old_logger
  end

  before do
    @defer = DeferInstance.new
    @defer.async = true
  end

  after { @defer.stop! }

  it 'supports timeout reporting' do
    @defer.timeout = 0.05

    m =
      track_log_messages do |messages|
        10.times { @defer.later('fast job') {  } }
        @defer.later 'weird slow job' do
          sleep
        end

        wait_for(200) { messages.length == 1 }
      end

    expect(m.length).to eq(1)
    expect(m[0][2]).to include('weird slow job')
  end

  it 'can pause and resume' do
    x = 1
    @defer.pause

    @defer.later { x = 2 }

    expect(@defer.length).to eq(1)

    @defer.do_all_work

    expect(x).to eq(2)

    @defer.resume

    @defer.later { x = 3 }

    wait_for(10) { x == 3 }

    expect(x).to eq(3)
  end

  it 'recovers from a crash / fork' do
    s = nil
    @defer.stop!
    wait_for(10) { @defer.stopped? }
    # hack allow thread to die
    sleep 0.005

    @defer.later { s = 'good' }

    wait_for(10) { s == 'good' }

    expect(s).to eq('good')
  end

  it 'can queue jobs properly' do
    s = nil

    @defer.later { s = 'good' }

    wait_for(10) { s == 'good' }

    expect(s).to eq('good')
  end
end
