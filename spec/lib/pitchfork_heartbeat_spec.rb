# frozen_string_literal: true

require "pitchfork"
require "pitchfork/configurator"
require "demon/discourse_vips"

RSpec.describe Pitchfork::Configurator do
  describe "#[]" do
    it "checks the remaining daemons when libvips and a plugin check fail" do
      configuration =
        described_class.new(config_file: Rails.root.join("config/pitchfork.conf.rb").to_s)
      failed_plugin = double(prefix: "failed_plugin", start: nil)
      healthy_plugin = double(prefix: "healthy_plugin", start: nil)
      checked = []
      log_output = StringIO.new
      logger = Logger.new(log_output)
      server = double(logger:)
      heartbeat = nil

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("UNICORN_SIDEKIQS").and_return("0")
      allow(GlobalSetting).to receive(:enable_vips_image_processing).and_return(true)
      allow(Rails).to receive(:logger).and_return(logger)
      allow(DiscoursePluginRegistry).to receive(:demon_processes).and_return(
        [failed_plugin, healthy_plugin],
      )
      allow(Demon::DiscourseVips).to receive(:start)
      allow(Demon::DiscourseVips).to receive(:ensure_running).and_raise("vips unavailable")
      allow(failed_plugin).to receive(:ensure_running).and_raise("plugin unavailable")
      allow(healthy_plugin).to receive(:ensure_running) { checked << :healthy_plugin }
      allow(Thread).to receive(:new) { |&block| heartbeat = block }
      configuration.stubs(:sleep).with(60).returns(nil).then.throws(:heartbeat_finished)

      configuration[:before_service_worker_ready].call(server, nil)
      catch(:heartbeat_finished) { heartbeat.call }

      expect(checked).to eq([:healthy_plugin])
      expect(log_output.string).to include("vips unavailable", "plugin unavailable")
    end
  end
end
