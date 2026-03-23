# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::Triggers::Schedule::V1 do
  describe ".identifier" do
    it "returns trigger:schedule" do
      expect(described_class.identifier).to eq("trigger:schedule")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".configuration_schema" do
    it "requires a cron expression" do
      schema = described_class.configuration_schema
      expect(schema[:cron][:type]).to eq(:string)
      expect(schema[:cron][:required]).to eq(true)
    end
  end

  describe ".output_schema" do
    it "includes timestamp" do
      expect(described_class.output_schema).to have_key(:timestamp)
    end
  end

  describe "#output" do
    it "returns the current timestamp" do
      freeze_time Time.utc(2026, 3, 18, 9, 0)
      trigger = described_class.new
      output = trigger.output
      expect(output[:timestamp]).to eq("2026-03-18T09:00:00Z")
    end
  end
end
