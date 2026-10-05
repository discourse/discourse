# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice do
  describe ".warn" do
    it "disables warning logs by default" do
      expect(SiteSetting.voice_verbose_logging).to eq(false)

      logs = track_log_messages { described_class.warn("[voice] chat operation failed") }

      expect(logs.warnings).to be_empty
    end

    it "logs warnings only while verbose logging is enabled" do
      logs =
        track_log_messages do
          SiteSetting.voice_verbose_logging = true
          described_class.warn("[voice] chat operation failed")
          SiteSetting.voice_verbose_logging = false
          described_class.warn("[voice] chat operation failed")
        end

      expect(logs.warnings).to eq(["[voice] chat operation failed"])
    end
  end
end
