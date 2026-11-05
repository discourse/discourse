# frozen_string_literal: true

require "rails_helper"

RSpec.describe Live do
  describe ".warn" do
    it "disables warning logs by default" do
      expect(SiteSetting.live_verbose_logging).to eq(false)

      logs = track_log_messages { described_class.warn("[live] chat operation failed") }

      expect(logs.warnings).to be_empty
    end

    it "logs warnings only while verbose logging is enabled" do
      logs =
        track_log_messages do
          SiteSetting.live_verbose_logging = true
          described_class.warn("[live] chat operation failed")
          SiteSetting.live_verbose_logging = false
          described_class.warn("[live] chat operation failed")
        end

      expect(logs.warnings).to eq(["[live] chat operation failed"])
    end
  end
end
