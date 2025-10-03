# frozen_string_literal: true

RSpec.describe WebHookEventsDailyAggregate do
  fab!(:web_hook)
  fab!(:event) do
    Fabricate(
      :web_hook_event,
      status: 200,
      web_hook: web_hook,
      created_at: 1.days.ago,
      duration: 280,
    )
  end
  fab!(:event_today) { Fabricate(:web_hook_event, status: 200, web_hook: web_hook, duration: 300) }

  fab!(:failed_event) do
    Fabricate(
      :web_hook_event,
      status: 400,
      created_at: 1.days.ago,
      web_hook: web_hook,
      duration: 200,
    )
  end

  fab!(:failed_event2) do
    Fabricate(
      :web_hook_event,
      status: 400,
      web_hook: web_hook,
      created_at: 1.days.ago,
      duration: 200,
    )
  end
  fab!(:failed_event_today) do
    Fabricate(:web_hook_event, status: 400, web_hook: web_hook, duration: 200)
  end
  describe ".purge_old" do
    before { SiteSetting.retain_web_hook_events_aggregate_days = 1 }

    it "should be able to purge old web hook event aggregates" do
      web_hook = Fabricate(:web_hook)
      WebHookEvent.create!(status: 200, web_hook: web_hook, created_at: 1.days.ago, duration: 180)
      WebHookEvent.create!(status: 200, web_hook: web_hook, created_at: 2.days.ago, duration: 180)

      yesterday_aggregate =
        WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 1.days.ago)

      WebHookEventsDailyAggregate.create!(
        web_hook_id: web_hook.id,
        date: 2.days.ago,
        created_at: 2.days.ago,
      )

      expect { described_class.purge_old }.to change { WebHookEventsDailyAggregate.count }.by(-1)

      expect(WebHookEventsDailyAggregate.find(yesterday_aggregate.id)).to eq(yesterday_aggregate)
    end
  end

  describe "aggregation works" do
    it "should be able to aggregate web hook events" do
      yesterday_aggregate =
        WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 1.days.ago)
      yesterday_events = [event, failed_event, failed_event2]

      expect(WebHookEventsDailyAggregate.count).to eq(1)
      expect(yesterday_aggregate.web_hook_id).to eq(web_hook.id)
      expect(yesterday_aggregate.date).to eq(1.days.ago.to_date)

      expect(yesterday_aggregate.mean_duration).to eq(
        yesterday_events.sum(&:duration) / yesterday_events.count,
      )
      expect(yesterday_aggregate.successful_event_count).to eq(1)
      expect(yesterday_aggregate.failed_event_count).to eq(2)
    end

    it "should be able to filter by day" do
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 1.days.ago)
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 0.days.ago)
      yesterday_events = [event, failed_event, failed_event2]
      today_events = [event_today, failed_event_today]

      yesterday_aggregate = WebHookEventsDailyAggregate.by_day(1.days.ago, 1.days.ago)
      expect(yesterday_aggregate.count).to eq(1)
      expect(yesterday_aggregate.first.date).to eq(1.days.ago.to_date)

      expect(WebHookEventsDailyAggregate.count).to eq(2)

      today_and_yesterday_aggregate = WebHookEventsDailyAggregate.by_day(1.days.ago, 0.days.ago)

      expect(today_and_yesterday_aggregate.count).to eq(2)
      expect(today_and_yesterday_aggregate.map(&:date)).to eq(
        [0.days.ago.to_date, 1.days.ago.to_date],
      )
      expect(today_and_yesterday_aggregate.map(&:mean_duration)).to eq(
        [
          today_events.sum(&:duration) / today_events.count,
          yesterday_events.sum(&:duration) / yesterday_events.count,
        ],
      )
    end

    it "should not create a new WebHookEventsDailyAggregate row if AggregateWebHooksEvents runs twice" do
      expect { Jobs::AggregateWebHooksEvents.new.execute(date: 1.days.ago) }.to change {
        WebHookEventsDailyAggregate.count
      }.by(1)

      expect { Jobs::AggregateWebHooksEvents.new.execute(date: 1.days.ago) }.not_to change {
        WebHookEventsDailyAggregate.count
      }
    end

    it "should not fail if there are no events" do
      expect { Jobs::AggregateWebHooksEvents.new.execute(date: 99.days.ago) }.not_to raise_error

      expect(WebHookEventsDailyAggregate.count).to eq(1)
    end
  end
end
