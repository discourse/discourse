# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Schedule::V1 do
  describe ".validate_configuration" do
    it "accepts valid rules" do
      config = { "rules" => [{ "interval" => "minutes", "minutes_between_triggers" => 5 }] }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).to be_empty
    end

    it "accepts valid cron rules" do
      config = { "rules" => [{ "interval" => "cron", "cron" => "0 9 * * *" }] }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).to be_empty
    end

    it "rejects empty rules" do
      config = { "rules" => [] }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).not_to be_empty
    end

    it "rejects invalid cron rules" do
      config = { "rules" => [{ "interval" => "cron", "cron" => "invalid" }] }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).not_to be_empty
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
