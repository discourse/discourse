# frozen_string_literal: true

require Rails.root.join(
          "db/post_migrate/20261028131123_fix_clear_slow_mode_timers_scheduled_in_hours.rb",
        )

RSpec.describe FixClearSlowModeTimersScheduledInHours do
  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  fab!(:topic)

  # How the AI tool's timers were scheduled: the end's epoch seconds, read as hours.
  def misscheduled_timer(ends_at, created_at: Time.zone.now)
    Fabricate(
      :topic_timer,
      topic:,
      status_type: TopicTimer.types[:clear_slow_mode],
      execute_at: created_at,
    ).tap { |timer| timer.update_columns(execute_at: created_at + ends_at.to_f.hours, created_at:) }
  end

  it "moves a timer back to the end it was meant to have" do
    timer = misscheduled_timer(2.hours.from_now)

    described_class.new.up

    expect(timer.reload.execute_at).to be_within(1.second).of(2.hours.from_now)
  end

  it "ends a timer whose meant end has passed, or can't be recovered, right away",
     :aggregate_failures do
    past = misscheduled_timer(1.day.ago, created_at: 2.days.ago)
    garbled =
      Fabricate(
        :topic_timer,
        topic: Fabricate(:topic),
        status_type: TopicTimer.types[:clear_slow_mode],
      ).tap { |timer| timer.update_columns(execute_at: 500.years.from_now) }

    described_class.new.up

    expect(past.reload.execute_at).to be_within(1.second).of(1.day.ago)
    expect(garbled.reload.execute_at).to be_within(1.minute).of(Time.zone.now)
  end

  it "leaves other timers alone" do
    close_timer =
      Fabricate(:topic_timer, topic:, status_type: TopicTimer.types[:close]).tap do |timer|
        timer.update_columns(execute_at: 500.years.from_now)
      end
    slow_mode_timer =
      Fabricate(
        :topic_timer,
        topic: Fabricate(:topic),
        status_type: TopicTimer.types[:clear_slow_mode],
      )

    expect { described_class.new.up }.not_to change {
      [close_timer.reload.execute_at, slow_mode_timer.reload.execute_at]
    }
  end
end
