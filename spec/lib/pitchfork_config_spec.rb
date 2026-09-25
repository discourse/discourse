# frozen_string_literal: true

require "pitchfork"

RSpec.describe Pitchfork::Configurator do
  describe "after_worker_timeout" do
    it "logs the backtrace and emits a worker timeout event" do
      config = described_class.new(config_file: Rails.root.join("config/pitchfork.conf.rb").to_s)
      log = StringIO.new
      Rails.stubs(:logger).returns(Logger.new(log))
      timeout_info = Struct.new(:thread).new(Thread.current)

      events =
        DiscourseEvent.track_events(:web_worker_timeout) do
          config[:after_worker_timeout].call(nil, nil, timeout_info)
        end

      expect(events).to eq(
        [{ event_name: :web_worker_timeout, params: [{ continue_on_error: true }] }],
      )
      expect(log.string).to include("Pitchfork worker is about to timeout", __FILE__)
    end
  end
end
