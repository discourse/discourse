# frozen_string_literal: true

RSpec.describe WebHookEvent do
  let(:event) { WebHookEvent.new(status: 200, web_hook: Fabricate(:web_hook)) }
  let(:failed_event) { WebHookEvent.new(status: 400, web_hook: Fabricate(:web_hook)) }

  it "removes its redelivery marker when destroyed" do
    event.save!
    marker = RedeliveringWebhookEvent.create!(web_hook_event: event)

    event.destroy!

    expect(RedeliveringWebhookEvent.exists?(marker.id)).to eq(false)
  end

  describe ".purge_old" do
    before { SiteSetting.retain_web_hook_events_period_days = 1 }

    it "purges old webhook events" do
      web_hook = Fabricate(:web_hook)
      web_hook_event = WebHookEvent.create!(status: 200, web_hook: web_hook)
      WebHookEvent.create!(status: 200, web_hook: web_hook, created_at: 2.days.ago)

      expect { described_class.purge_old }.to change { WebHookEvent.count }.by(-1)

      expect(WebHookEvent.find(web_hook_event.id)).to eq(web_hook_event)
    end
  end

  describe "#update_web_hook_delivery_status" do
    it "update last delivery status for associated WebHook record" do
      event.update_web_hook_delivery_status

      expect(event.web_hook.last_delivery_status).to eq(WebHook.last_delivery_statuses[:successful])
    end

    it "sets last delivery status to failed" do
      failed_event.update_web_hook_delivery_status

      expect(failed_event.web_hook.last_delivery_status).to eq(
        WebHook.last_delivery_statuses[:failed],
      )
    end
  end
end
