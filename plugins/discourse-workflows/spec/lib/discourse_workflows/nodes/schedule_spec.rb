# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Schedule::V1 do
  describe ".validate_configuration" do
    it "accepts valid rules" do
      config = { "rule" => { "interval" => [{ "field" => "minutes", "minutesInterval" => 5 }] } }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).to be_empty
    end

    it "accepts valid cron rules" do
      config = {
        "rule" => {
          "interval" => [{ "field" => "cronExpression", "expression" => "0 9 * * *" }],
        },
      }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).to be_empty
    end

    it "rejects empty rules" do
      config = { "rule" => { "interval" => [] } }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).not_to be_empty
    end

    it "rejects invalid cron rules" do
      config = {
        "rule" => {
          "interval" => [{ "field" => "cronExpression", "expression" => "invalid" }],
        },
      }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).not_to be_empty
    end

    it "accepts multiple rules" do
      config = {
        "rule" => {
          "interval" => Array.new(8) { { "field" => "minutes", "minutesInterval" => 5 } },
        },
      }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).to be_empty
    end

    it "rejects seconds rules" do
      config = { "rule" => { "interval" => [{ "field" => "seconds", "secondsInterval" => 30 }] } }
      errors = ActiveModel::Errors.new(Object.new)
      described_class.validate_configuration(config, errors)
      expect(errors).not_to be_empty
    end
  end
end
