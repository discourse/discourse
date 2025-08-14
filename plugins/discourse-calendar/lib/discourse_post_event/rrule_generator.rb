# frozen_string_literal: true

require "rrule"

class RRuleGenerator
  def self.generate(
    starts_at:,
    timezone: "UTC",
    max_years: nil,
    recurrence: "every_week",
    recurrence_until: nil,
    dtstart: nil
  )
    rrule = generate_hash(RRuleConfigurator.rule(recurrence_until:, recurrence:, starts_at:))
    rrule = set_mandatory_options(rrule, starts_at)

    ::RRule::Rule
      .new(stringify(rrule), dtstart: starts_at, tzid: timezone, dtstart:)
      .between(Time.current, Time.current + 14.months)
      .first(RRuleConfigurator.how_many_recurring_events(recurrence:, max_years:))
  end

  def self.generate_string(
    starts_at:,
    timezone: "UTC",
    max_years: nil,
    recurrence: "every_week",
    recurrence_until: nil,
    dtstart: nil
  )
    rrule = generate_hash(RRuleConfigurator.rule(recurrence_until:, recurrence:, starts_at:))
    rrule = set_mandatory_options(rrule, starts_at)

    # Format as multi-line RFC 5545 format for FullCalendar
    # Use local time format without Z suffix to avoid timezone conversion issues
    dtstart_line = "DTSTART:#{dtstart.strftime("%Y%m%dT%H%M%S")}" if dtstart
    rrule_line = "RRULE:#{stringify(rrule)}"

    if dtstart_line
      "#{dtstart_line}\n#{rrule_line}"
    else
      rrule_line
    end
  end

  private

  def self.stringify(rrule)
    rrule.map { |k, v| "#{k}=#{v}" }.join(";")
  end

  def self.generate_hash(rrule)
    rrule
      .split(";")
      .each_with_object({}) do |rr, h|
        key, value = rr.split("=")
        h[key] = value
      end
  end

  def self.set_mandatory_options(rrule, time)
    rrule["BYHOUR"] = time.strftime("%H")
    rrule["BYMINUTE"] = time.strftime("%M")
    rrule["INTERVAL"] ||= 1
    rrule["WKST"] = "MO" # considers Monday as the first day of the week
    rrule
  end
end
