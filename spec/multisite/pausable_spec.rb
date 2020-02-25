# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Pausing/Unpausing Sidekiq", type: :multisite do

  describe '#pause!, #unpause! and #paused?' do
    it "can pause and unpause" do
      Sidekiq.pause!
      expect(Sidekiq.paused?).to eq(true)

      test_multisite_connection('second') do
        expect(Sidekiq.paused?).to eq(false)
      end

      Sidekiq.unpause!

      expect(Sidekiq.paused?).to eq(false)

      test_multisite_connection('second') do
        Sidekiq.pause!("test")
        expect(Sidekiq.paused?).to eq(true)
      end

      expect(Sidekiq.paused_dbs).to eq(["second"])

      Sidekiq.unpause_all!

      RailsMultisite::ConnectionManagement.each_connection do
        expect(Sidekiq.paused?).to eq(false)
      end
    end
  end
end

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

  describe 'when sidekiq is paused', type: :multisite do
    let(:middleware) { Sidekiq::Pausable.new }

    def call_middleware(db = RailsMultisite::ConnectionManagement::DEFAULT)
      middleware.call(Jobs::PostAlert.new, {
        "args" => [{ "current_site_id" => db }]
      }, "critical") do
        yield
      end
    end

    it 'should delay the job' do
      Sidekiq.pause!

      called = false
      called2 = false
      call_middleware { called = true }

      expect(called).to eq(false)

      test_multisite_connection('second') do
        call_middleware('second') { called2 = true }
        expect(called2).to eq(true)
      end

      Sidekiq.unpause!
      call_middleware { called = true }

      expect(called).to eq(true)

      test_multisite_connection('second') do
        Sidekiq.pause!
        call_middleware('second') { called2 = false }
        expect(called2).to eq(true)
      end
    end
  end
end
