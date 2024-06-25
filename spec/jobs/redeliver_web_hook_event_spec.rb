# frozen_string_literal: true

require "excon"

RSpec.describe Jobs::RedeliverWebHookEvent do
  subject(:job) { described_class.new }

  fab!(:web_hook)
  fab!(:post)

  REDELIVERED = "redelivered"

  describe "#redeliver_webhook!" do
    fab!(:web_hook_event) do
      Fabricate(:web_hook_event, web_hook: web_hook, status: 404, headers: JSON.dump(aa: "1"))
    end

    it "redelivers a webhook event" do
      stub_request(:post, web_hook.payload_url).with(
        body: "{\"some_key\":\"some_value\"}",
        headers: {
          "aa" => 1,
        },
      ).to_return(status: 200, body: "", headers: {})

      job.execute(web_hook_id: web_hook.id, web_hook_event_id: web_hook_event.id)

      event = WebHookEvent.find_by(id: web_hook_event.id)
      expect(event.status).to eq(200)

      messages =
        MessageBus.track_publish do
          job.execute(web_hook_id: web_hook.id, web_hook_event_id: web_hook_event.id)
        end

      expect(messages.size).to eq(1)
    end
  end
end
