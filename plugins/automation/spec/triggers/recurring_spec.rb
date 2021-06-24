# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'Recurring' do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::RECURRING, script: 'nothing_about_us')
  end

  context 'updating trigger' do
    context 'date is in future' do
      it 'creates a pending trigger' do
        expect {
          automation.upsert_field!('starts_at', 'date_time', { value: 2.hours.from_now }, target: 'trigger')
        }.to change {
          DiscourseAutomation::PendingAutomation.count
        }.by(1)

        expect(DiscourseAutomation::PendingAutomation.last.execute_at).to be_within_one_minute_of(2.hours.from_now)
      end
    end

    context 'date is in past' do
      it 'doesn’t create a pending trigger' do
        expect {
          automation.upsert_field!('starts_at', 'date_time', { value: 2.hours.ago }, target: 'trigger')
        }.to change {
          DiscourseAutomation::PendingAutomation.count
        }.by(0)
      end
    end
  end

  context 'trigger is called' do
    before do
      freeze_time Time.parse('2021-06-04 10:00')
      automation.upsert_field!('starts_at', 'date_time', { value: 2.hours.ago }, target: 'trigger')
      automation.upsert_field!('recurrence', 'choices', { value: 'every_week' }, target: 'trigger')
    end

    it 'creates the next iteration' do
      expect {
        automation.trigger!
      }.to change {
        DiscourseAutomation::PendingAutomation.count
      }.by(1)

      pending_automation = DiscourseAutomation::PendingAutomation.last

      starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
      expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 7.days)
    end

    context 'every_month' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_month' }, target: 'trigger')
      end

      it 'creates the next iteration one month later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
        expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 1.month)
      end
    end

    context 'every_day' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_day' }, target: 'trigger')
      end

      it 'creates the next iteration one day later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
        expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 1.day)
      end
    end

    context 'every_weekday' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_weekday' }, target: 'trigger')
      end

      it 'creates the next iteration one day after without Saturday/Sunday' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
        expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 3.day)
      end
    end

    context 'every_hour' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_hour' }, target: 'trigger')
      end

      it 'creates the next iteration one hour later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        expect(pending_automation.execute_at).to be_within_one_minute_of((Time.zone.now + 1.hour).beginning_of_hour)
      end
    end

    context 'every_minute' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_minute' }, target: 'trigger')
      end

      it 'creates the next iteration one minute later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        expect(pending_automation.execute_at).to be_within_one_minute_of((Time.zone.now + 1.minute).beginning_of_minute)
      end
    end

    context 'every_year' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_year' }, target: 'trigger')
      end

      it 'creates the next iteration one year later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
        expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 1.year)
      end
    end

    context 'every_other_week' do
      before do
        automation.upsert_field!('recurrence', 'choices', { value: 'every_other_week' }, target: 'trigger')
      end

      it 'creates the next iteration one month later' do
        automation.trigger!

        pending_automation = DiscourseAutomation::PendingAutomation.last
        starts_at = Time.parse(automation.trigger_field('starts_at')['value'])
        expect(pending_automation.execute_at).to be_within_one_minute_of(starts_at + 2.weeks)
      end
    end
  end
end
