# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CronParser do
  describe ".matches?" do
    it "matches a wildcard expression" do
      time = Time.utc(2026, 3, 18, 14, 30)
      expect(described_class.matches?("* * * * *", time)).to be(true)
    end

    it "matches a specific minute and hour" do
      time = Time.utc(2026, 3, 18, 9, 0)
      expect(described_class.matches?("0 9 * * *", time)).to be(true)
    end

    it "rejects a non-matching minute" do
      time = Time.utc(2026, 3, 18, 9, 15)
      expect(described_class.matches?("0 9 * * *", time)).to be(false)
    end

    it "handles step values" do
      time = Time.utc(2026, 3, 18, 14, 15)
      expect(described_class.matches?("*/15 * * * *", time)).to be(true)

      time = Time.utc(2026, 3, 18, 14, 10)
      expect(described_class.matches?("*/15 * * * *", time)).to be(false)
    end

    it "handles ranges" do
      time = Time.utc(2026, 3, 18, 10, 0) # Wednesday
      expect(described_class.matches?("0 * * * 1-5", time)).to be(true)

      time = Time.utc(2026, 3, 22, 10, 0) # Sunday
      expect(described_class.matches?("0 * * * 1-5", time)).to be(false)
    end

    it "handles lists" do
      time = Time.utc(2026, 3, 18, 9, 0)
      expect(described_class.matches?("0 9,17 * * *", time)).to be(true)

      time = Time.utc(2026, 3, 18, 12, 0)
      expect(described_class.matches?("0 9,17 * * *", time)).to be(false)
    end

    it "handles ranges with steps" do
      time = Time.utc(2026, 3, 18, 10, 0)
      expect(described_class.matches?("0 8-18/2 * * *", time)).to be(true)

      time = Time.utc(2026, 3, 18, 11, 0)
      expect(described_class.matches?("0 8-18/2 * * *", time)).to be(false)
    end

    it "handles day-of-week 0 and 7 both as Sunday" do
      sunday = Time.utc(2026, 3, 22, 10, 0) # Sunday
      expect(described_class.matches?("0 10 * * 0", sunday)).to be(true)
      expect(described_class.matches?("0 10 * * 7", sunday)).to be(true)
    end

    it "handles optional seconds" do
      time = Time.utc(2026, 3, 18, 9, 0, 30)
      expect(described_class.matches?("30 0 9 * * *", time)).to be(true)
      expect(described_class.matches?("0 9 * * *", time)).to be(false)
    end

    it "handles month and weekday names" do
      time = Time.utc(2026, 3, 18, 9, 0) # Wednesday
      expect(described_class.matches?("0 9 * mar MON-FRI", time)).to be(true)
    end

    it "uses standard cron semantics when day-of-month and day-of-week are both restricted" do
      monday = Time.utc(2026, 6, 8, 9, 0) # Monday
      first_of_month = Time.utc(2026, 4, 1, 9, 0) # Wednesday, first of month
      neither = Time.utc(2026, 6, 9, 9, 0) # Tuesday

      expect(described_class.matches?("0 9 1 * 1", monday)).to be(true)
      expect(described_class.matches?("0 9 1 * 1", first_of_month)).to be(true)
      expect(described_class.matches?("0 9 1 * 1", neither)).to be(false)
    end

    it "returns false for invalid expressions" do
      time = Time.utc(2026, 3, 18, 14, 30)
      expect(described_class.matches?("invalid", time)).to be(false)
      expect(described_class.matches?("", time)).to be(false)
      expect(described_class.matches?(nil, time)).to be(false)
      expect(described_class.matches?("10-5 * * * *", time)).to be(false)
      expect(described_class.matches?("*/0 * * * *", time)).to be(false)
      expect(described_class.matches?("1,,2 * * * *", time)).to be(false)
      expect(described_class.matches?("* * * * ?", time)).to be(false)
    end
  end

  describe ".valid?" do
    it "checks expression syntax without needing a time argument" do
      expect(described_class.valid?("* * * * *")).to be(true)
      expect(described_class.valid?("0 9 * * MON-FRI")).to be(true)
      expect(described_class.valid?("invalid")).to be(false)
      expect(described_class.valid?(nil)).to be(false)
    end

    it "rejects field-count mismatches that .matches? cannot surface" do
      expect(described_class.valid?("* * *")).to be(false)
      expect(described_class.valid?("60 * * * *")).to be(false)
      expect(described_class.valid?("* 25 * * *")).to be(false)
    end
  end

  describe ".minute_granularity?" do
    it "accepts 5-field cron and 6-field cron fixed to second zero" do
      expect(described_class.minute_granularity?("0 9 * * *")).to be(true)
      expect(described_class.minute_granularity?("0 0 9 * * *")).to be(true)
    end

    it "rejects sub-minute cron expressions" do
      expect(described_class.minute_granularity?("*/10 * * * * *")).to be(false)
      expect(described_class.minute_granularity?("0,30 * * * * *")).to be(false)
    end
  end
end
