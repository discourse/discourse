# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Schedule::Payload do
  describe ".build" do
    it "returns compatible timestamp fields" do
      payload = described_class.build(time: Time.utc(2026, 3, 18, 9, 0), timezone: "UTC")

      expect(payload).to include(
        "timestamp" => "2026-03-18T09:00:00.000Z",
        "readable_date" => "March 18th 2026, 9:00:00 am",
        "readable_time" => "9:00:00 am",
        "day_of_week" => "Wednesday",
        "year" => "2026",
        "month" => "March",
        "day_of_month" => "18",
        "hour" => "09",
        "minute" => "00",
        "second" => "00",
        "timezone" => "UTC (UTC+00:00)",
      )
    end

    it "formats fields in the resolved workflow timezone" do
      payload = described_class.build(time: Time.utc(2026, 3, 18, 8, 0), timezone: "Europe/Paris")

      expect(payload).to include(
        "timestamp" => "2026-03-18T09:00:00.000+01:00",
        "hour" => "09",
        "timezone" => "Europe/Paris (UTC+01:00)",
      )
    end
  end
end
