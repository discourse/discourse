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
      .new(stringify(rrule), dtstart: starts_at, tzid: timezone)
      .between(Time.current, Time.current + 14.months)
      .first(RRuleConfigurator.how_many_recurring_events(recurrence:, max_years:))
  end

  def self.generate_string(
    starts_at:,
    timezone: "UTC",
    max_years: nil,
    recurrence: "every_week",
    recurrence_until: nil,
    dtstart: nil,
    show_local_time: false
  )
    rrule = generate_hash(RRuleConfigurator.rule(recurrence_until:, recurrence:, starts_at:))
    rrule = set_mandatory_options(rrule, starts_at)
    rrule_line = "RRULE:#{stringify(rrule)}"

    if dtstart
      if show_local_time
        dtstart_line = "DTSTART:#{dtstart.strftime("%Y%m%dT%H%M%S")}"
      else
        dtstart_line = "DTSTART:#{dtstart.utc.strftime("%Y%m%dT%H%M%SZ")}"
      end
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
    rrule["INTERVAL"] ||= 1
    rrule["WKST"] = "MO" # considers Monday as the first day of the week
    rrule
  end
end
