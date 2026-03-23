# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::CronParser do
  describe ".matches?" do
    it "matches a wildcard expression" do
      time = Time.utc(2026, 3, 18, 14, 30)
      expect(described_class.matches?("* * * * *", time)).to eq(true)
    end

    it "matches a specific minute and hour" do
      time = Time.utc(2026, 3, 18, 9, 0)
      expect(described_class.matches?("0 9 * * *", time)).to eq(true)
    end

    it "rejects a non-matching minute" do
      time = Time.utc(2026, 3, 18, 9, 15)
      expect(described_class.matches?("0 9 * * *", time)).to eq(false)
    end

    it "handles step values" do
      time = Time.utc(2026, 3, 18, 14, 15)
      expect(described_class.matches?("*/15 * * * *", time)).to eq(true)

      time = Time.utc(2026, 3, 18, 14, 10)
      expect(described_class.matches?("*/15 * * * *", time)).to eq(false)
    end

    it "handles ranges" do
      time = Time.utc(2026, 3, 18, 10, 0) # Wednesday
      expect(described_class.matches?("0 * * * 1-5", time)).to eq(true)

      time = Time.utc(2026, 3, 22, 10, 0) # Sunday
      expect(described_class.matches?("0 * * * 1-5", time)).to eq(false)
    end

    it "handles lists" do
      time = Time.utc(2026, 3, 18, 9, 0)
      expect(described_class.matches?("0 9,17 * * *", time)).to eq(true)

      time = Time.utc(2026, 3, 18, 12, 0)
      expect(described_class.matches?("0 9,17 * * *", time)).to eq(false)
    end

    it "handles ranges with steps" do
      time = Time.utc(2026, 3, 18, 10, 0)
      expect(described_class.matches?("0 8-18/2 * * *", time)).to eq(true)

      time = Time.utc(2026, 3, 18, 11, 0)
      expect(described_class.matches?("0 8-18/2 * * *", time)).to eq(false)
    end

    it "handles day-of-week 0 and 7 both as Sunday" do
      sunday = Time.utc(2026, 3, 22, 10, 0) # Sunday
      expect(described_class.matches?("0 10 * * 0", sunday)).to eq(true)
      expect(described_class.matches?("0 10 * * 7", sunday)).to eq(true)
    end

    it "uses standard cron semantics when day-of-month and day-of-week are both restricted" do
      monday = Time.utc(2026, 6, 8, 9, 0) # Monday
      first_of_month = Time.utc(2026, 4, 1, 9, 0) # Wednesday, first of month
      neither = Time.utc(2026, 6, 9, 9, 0) # Tuesday

      expect(described_class.matches?("0 9 1 * 1", monday)).to eq(true)
      expect(described_class.matches?("0 9 1 * 1", first_of_month)).to eq(true)
      expect(described_class.matches?("0 9 1 * 1", neither)).to eq(false)
    end

    it "returns false for invalid expressions" do
      time = Time.utc(2026, 3, 18, 14, 30)
      expect(described_class.matches?("invalid", time)).to eq(false)
      expect(described_class.matches?("", time)).to eq(false)
      expect(described_class.matches?(nil, time)).to eq(false)
      expect(described_class.matches?("10-5 * * * *", time)).to eq(false)
      expect(described_class.matches?("*/0 * * * *", time)).to eq(false)
      expect(described_class.matches?("1,,2 * * * *", time)).to eq(false)
      expect(described_class.matches?("* * * * MON", time)).to eq(false)
    end
  end

  describe ".valid?" do
    it "accepts valid expressions" do
      expect(described_class.valid?("* * * * *")).to eq(true)
      expect(described_class.valid?("0 9 * * 1-5")).to eq(true)
      expect(described_class.valid?("*/15 * * * *")).to eq(true)
    end

    it "rejects invalid expressions" do
      expect(described_class.valid?("invalid")).to eq(false)
      expect(described_class.valid?("* * *")).to eq(false)
      expect(described_class.valid?(nil)).to eq(false)
      expect(described_class.valid?("60 * * * *")).to eq(false)
      expect(described_class.valid?("* 25 * * *")).to eq(false)
      expect(described_class.valid?("10-5 * * * *")).to eq(false)
      expect(described_class.valid?("*/0 * * * *")).to eq(false)
      expect(described_class.valid?("1,,2 * * * *")).to eq(false)
      expect(described_class.valid?("* * * * MON")).to eq(false)
    end
  end
end
