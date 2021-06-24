# frozen_string_literal: true

DiscourseAutomation::Triggerable::RECURRING = 'recurring'

RECURRENCE_CHOICES = [
  { id: 'every_minute', name: 'discourse_automation.triggerables.recurring.recurrences.every_minute' },
  { id: 'every_hour', name: 'discourse_automation.triggerables.recurring.recurrences.every_hour' },
  { id: 'every_day', name: 'discourse_automation.triggerables.recurring.recurrences.every_day' },
  { id: 'every_weekday', name: 'discourse_automation.triggerables.recurring.recurrences.every_weekday' },
  { id: 'every_week', name: 'discourse_automation.triggerables.recurring.recurrences.every_week' },
  { id: 'every_other_week', name: 'discourse_automation.triggerables.recurring.recurrences.every_other_week' },
  { id: 'every_month', name: 'discourse_automation.triggerables.recurring.recurrences.every_month' },
  { id: 'every_year', name: 'discourse_automation.triggerables.recurring.recurrences.every_year' },
]

def setup_pending_automation(automation, fields)
  automation.pending_automations.destroy_all

  start_date = fields.dig('start_date', 'value')
  return if !start_date
  start_date = Time.parse(start_date)

  expected_recurrence = fields.dig('recurrence', 'value')
  return if !expected_recurrence

  byday = start_date.strftime('%A').upcase[0, 2]

  case expected_recurrence
  when 'every_day'
    next_trigger_date = RRule::Rule
      .new('FREQ=DAILY', dtstart: start_date)
      .between(Time.now.end_of_day, 2.days.from_now)
      .first
  when 'every_month'
    count = 0
    (start_date.beginning_of_month.to_date..start_date.end_of_month.to_date).each do |date|
      count += 1 if date.strftime('%A') == start_date.strftime('%A')
      break if date.day == start_date.day
    end

    next_trigger_date = RRule::Rule
      .new("FREQ=MONTHLY;BYDAY=#{count}#{byday}", dtstart: start_date)
      .between(Time.now, 2.months.from_now)
      .first
  when 'every_weekday'
    next_trigger_date = RRule::Rule
      .new('FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR', dtstart: start_date)
      .between(Time.now.end_of_day, 3.days.from_now)
      .first
  when 'every_week'
    next_trigger_date = RRule::Rule
      .new("FREQ=WEEKLY;BYDAY=#{byday}", dtstart: start_date)
      .between(Time.now.end_of_week, 2.weeks.from_now)
      .first
  when 'every_other_week'
    next_trigger_date = RRule::Rule
      .new("FREQ=WEEKLY;INTERVAL=2;BYDAY=#{byday}", dtstart: start_date)
      .between(Time.now.end_of_week, Time.now + 2.months)
      .first
  when 'every_hour'
    next_trigger_date = (Time.zone.now + 1.hour).beginning_of_hour
  when 'every_minute'
    next_trigger_date = (Time.zone.now + 1.minute).beginning_of_minute
  when 'every_year'
    next_trigger_date = RRule::Rule
      .new("FREQ=YEARLY", dtstart: start_date)
      .between(Time.now, 2.years.from_now)
      .first
  end

  if next_trigger_date && next_trigger_date > Time.zone.now
    automation
      .pending_automations
      .create!(execute_at: next_trigger_date)
  end
end

DiscourseAutomation::Triggerable.add(DiscourseAutomation::Triggerable::RECURRING) do
  field :recurrence, component: :choices, extra: { content: RECURRENCE_CHOICES }
  field :start_date, component: :date_time

  on_update { |automation, fields| setup_pending_automation(automation, fields) }
  on_call { |automation, fields| setup_pending_automation(automation, fields) }
end
