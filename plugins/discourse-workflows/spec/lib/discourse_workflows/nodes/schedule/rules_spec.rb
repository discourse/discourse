# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Schedule::Rules do
  describe ".to_cron_expression" do
    it "converts minute intervals" do
      rule = { "field" => "minutes", "minutesInterval" => 5 }

      expect(described_class.to_cron_expression(rule)).to eq("*/5 * * * *")
    end

    it "converts weekly intervals" do
      rule = {
        "field" => "weeks",
        "triggerAtDay" => [1, 3],
        "triggerAtHour" => 9,
        "triggerAtMinute" => 15,
      }

      expect(described_class.to_cron_expression(rule)).to eq("15 9 * * 1,3")
    end

    it "passes cron expressions through" do
      rule = { "field" => "cronExpression", "expression" => "0 9 * * *" }

      expect(described_class.to_cron_expression(rule)).to eq("0 9 * * *")
    end
  end

  describe ".valid?" do
    it "accepts valid interval rules" do
      expect(described_class.valid?({ "field" => "minutes", "minutesInterval" => 5 })).to be(true)
      expect(
        described_class.valid?(
          {
            "field" => "months",
            "monthsInterval" => 2,
            "triggerAtDayOfMonth" => 15,
            "triggerAtHour" => 9,
            "triggerAtMinute" => 0,
          },
        ),
      ).to be(true)
    end

    it "rejects seconds rules" do
      expect(described_class.valid?({ "field" => "seconds", "secondsInterval" => 30 })).to be(false)
    end

    it "rejects out-of-range values" do
      expect(described_class.valid?({ "field" => "minutes", "minutesInterval" => 0 })).to be(false)
      expect(described_class.valid?({ "field" => "hours", "hoursInterval" => 24 })).to be(false)
      expect(
        described_class.valid?({ "field" => "weeks", "weeksInterval" => 1, "triggerAtDay" => [7] }),
      ).to be(false)
    end

    it "rejects non-numeric weekdays" do
      expect(
        described_class.valid?(
          { "field" => "weeks", "weeksInterval" => 1, "triggerAtDay" => ["Sunday"] },
        ),
      ).to be(false)
    end

    it "requires cron expressions to have minute granularity" do
      expect(
        described_class.valid?({ "field" => "cronExpression", "expression" => "0 9 * * *" }),
      ).to be(true)
      expect(
        described_class.valid?({ "field" => "cronExpression", "expression" => "*/10 * * * * *" }),
      ).to be(false)
    end
  end
end
