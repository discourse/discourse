# frozen_string_literal: true

RSpec.describe WebHookEventsDailyAggregate do
  let(:web_hook) { Fabricate(:web_hook) }
  let(:event) { WebHookEvent.new(status: 200, web_hook: web_hook, created_at: 2.days.ago) }
  let(:failed_event) { WebHookEvent.new(status: 400, web_hook: web_hook, created_at: 2.days.ago) }

  describe "aggregation works" do
    it "should be able to aggregate web hook events" do
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 2.days.ago)
      expect(WebHookEventsDailyAggregate.count).to eq(1)
      expect(WebHookEventsDailyAggregate.first.web_hook_id).to eq(web_hook.id)
      expect(WebHookEventsDailyAggregate.first.date).to eq(2.days.ago.to_date)
    end

    it "should be able to filter by day" do
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 2.days.ago)
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 3.days.ago)
      WebHookEventsDailyAggregate.create!(web_hook_id: web_hook.id, date: 4.days.ago)

      expect(WebHookEventsDailyAggregate.by_day(2.days.ago, 2.days.ago).count).to eq(1)
      expect(WebHookEventsDailyAggregate.by_day(2.days.ago, 2.days.ago).first.date).to eq(
        2.days.ago.to_date,
      )
      expect(WebHookEventsDailyAggregate.count).to eq(3)
    end
  end
end
