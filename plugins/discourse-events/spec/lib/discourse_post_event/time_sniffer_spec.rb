# frozen_string_literal: true

describe TimeSniffer do
  before { freeze_time DateTime.parse("2020-04-24 14:10") }

  let(:default_context) do
    {
      at: DateTime.parse("2020-1-20 00:00:00"),
      timezone: "EST",
      date_order: :sane,
      matchers: %i[tomorrow date time],
      raise_errors: true,
    }
  end

  define_method(:expect_parsed_as_interval) do |str, from:, to:, context: default_context|
    Time.use_zone(context[:timezone]) do
      expect(TimeSniffer.new(str, **context).sniff).to(
        eq(TimeSniffer::Interval.new(Time.zone.parse(from), Time.zone.parse(to))),
      )
    end
  end

  define_method(:expect_parsed_as_event) do |str, at, context: default_context|
    Time.use_zone(context[:timezone]) do
      expect(TimeSniffer.new(str, **context).sniff).to(
        eq(TimeSniffer::Event.new(Time.zone.parse(at))),
      )
    end
  end

  define_method(:expect_parsed_as_nil) do |str, context: default_context|
    expect(TimeSniffer.new(str, **context).sniff).to(eq(nil))
  end

  it "should support tomorrow with a timezone" do
    expect_parsed_as_interval("tomorrow", from: "2020-1-21 EST", to: "2020-1-22 EST")
  end

  it "should support Tomorrow" do
    expect_parsed_as_interval("Tomorrow", from: "2020-1-21", to: "2020-1-22")
  end

  it "should support 14:00" do
    expect_parsed_as_event("14:00", "2020-1-20 14:00 EST")
  end

  it "should support 14:24" do
    expect_parsed_as_event("14:24", "2020-1-20 14:24 EST")
  end

  it "should support 15:00 with emojis" do
    expect_parsed_as_event("😊😊😊😊15:00😊😊😊😊", "2020-1-20 15:00 EST")
  end

  it "should support 14:00 - 15:00" do
    expect_parsed_as_interval(
      "14:00 - 15:00",
      from: "2020-1-20 14:00 EST",
      to: "2020-1-20 15:00 EST",
    )
  end

  it "should support too many times" do
    expect_parsed_as_interval(
      "14:00 - 15:00 asotuhosthu 16:00",
      from: "2020-1-20 14:00 EST",
      to: "2020-1-20 15:00 EST",
    )
  end

  it "should support too many times" do
    expect_parsed_as_interval(
      "14:00 - 15:00 asotuhosthu 16:00",
      from: "2020-1-20 14:00 EST",
      to: "2020-1-20 15:00 EST",
    )
  end

  it "should support a date" do
    expect_parsed_as_interval("31/3/25", from: "2025-3-31 00:00 EST", to: "2025-4-1 00:00 EST")
  end

  it "should support a date in the past century" do
    expect_parsed_as_interval("31/3/75", from: "1975-3-31 00:00 EST", to: "1975-4-1 00:00 EST")
  end

  it "should support a date with a year with 4 digits" do
    expect_parsed_as_interval("31/3/2021", from: "2021-3-31 00:00 EST", to: "2021-4-1 00:00 EST")
  end

  it "should support a date with hyphens" do
    expect_parsed_as_interval("31-3-25", from: "2025-3-31 00:00 EST", to: "2025-4-1 00:00 EST")
  end

  it "should support a date with a time" do
    expect_parsed_as_event("31-3-25 08:00", "2025-3-31 08:00 EST")
  end

  it "should support a date with a time with non-zero minutes" do
    expect_parsed_as_event("31-3-25 08:45", "2025-3-31 08:45 EST")
  end

  it "should support a date with a time and a timezone" do
    expect_parsed_as_event(
      "31-3-25 08:00 UTC",
      "2025-3-31 08:00:00 UTC",
      context: default_context.merge(timezone: "EST"),
    )
  end

  it "should support a date with a time and a timezone" do
    expect_parsed_as_event(
      "31-3-25 08:00UTC",
      "2025-3-31 08:00:00 UTC",
      context: default_context.merge(timezone: "EST"),
    )
  end

  it "should support a date with a time and a timezone" do
    expect_parsed_as_event(
      "31-3-25 08:00Z",
      "2025-3-31 08:00:00 UTC",
      context: default_context.merge(timezone: "EST"),
    )
  end

  it "should support a date range" do
    expect_parsed_as_interval(
      "25/2/21 - 10/3/22",
      from: "2021-2-25 00:00 EST",
      to: "2022-3-11 00:00 EST",
    )
  end

  it "should support a date range" do
    expect_parsed_as_interval(
      "25/2/21 - 10/3/22 14:00",
      from: "2021-2-25 00:00 EST",
      to: "2022-3-10 14:00 EST",
    )
  end

  it "should support a date range with two times" do
    expect_parsed_as_interval(
      "25/2/21 9:00 - 10/3/22 14:00",
      from: "2021-2-25 09:00 EST",
      to: "2022-3-10 14:00 EST",
    )
  end

  it "should support a date range with two times where the second is relative to the first" do
    expect_parsed_as_interval(
      "25/2/21 9:00 - 14:00",
      from: "2021-2-25 09:00 EST",
      to: "2021-2-25 14:00 EST",
    )
  end

  it "should correctly handle timezones in future" do
    expect_parsed_as_event(
      "24/06/2020 14:23",
      "2020-06-24 14:23 CEST",
      context: default_context.merge(timezone: "Europe/Paris"),
    )
  end

  it "should not find a time in a random number" do
    expect_parsed_as_nil("1500")
  end

  it "should not find a time in random numbers and an emoji" do
    expect_parsed_as_nil("15😊00")
  end

  it "shouldn't match a date starting with the year" do
    expect_parsed_as_nil("2020-03-27")
    expect_parsed_as_nil("foo 2020-03-27")
  end
end
