# frozen_string_literal: true

RSpec.describe Jobs::RedeliverWebHookEvents do
  subject(:job) { described_class.new }

  fab!(:web_hook)
  fab!(:web_hook_event1) do
    Fabricate(
      :web_hook_event,
      web_hook: web_hook,
      payload: "abc",
      headers: JSON.dump(aa: "1", bb: "2"),
    )
  end

  fab!(:web_hook_event2) do
    Fabricate(
      :web_hook_event,
      web_hook: web_hook,
      payload: "abc",
      headers: JSON.dump(aa: "1", bb: "2"),
    )
  end

  fab!(:redelivering_webhook_event) do
    Fabricate(:redelivering_webhook_event, web_hook_event_id: web_hook_event1.id)
  end

  it "redelivers webhook events" do
    stub_request(:post, web_hook.payload_url).with(
      body: "abc",
      headers: {
        "aa" => 1,
        "bb" => 2,
      },
    ).to_return(status: 400, body: "", headers: {})

    messages =
      MessageBus.track_publish { job.execute(web_hook: web_hook, web_hook_event: web_hook_event1) }

    expect(RedeliveringWebhookEvent.count).to eq(0)
    expect(messages.count).to eq(1)
    expect(messages.first.data).to include(type: "redelivered")
  end

  it "restricts the redelivery MessageBus publish to the admins group" do
    stub_request(:post, web_hook.payload_url).to_return(status: 200, body: "", headers: {})

    messages =
      MessageBus.track_publish("/web_hook_events/#{web_hook.id}") do
        job.execute(web_hook: web_hook, web_hook_event: web_hook_event1)
      end

    expect(RedeliveringWebhookEvent.count).to eq(0)
    expect(messages.size).to eq(1)
    expect(messages.first.data).to include(type: "redelivered")
    expect(messages.first.data[:web_hook_event]).to include(payload: "abc")
    expect(messages.first.group_ids).to eq([Group::AUTO_GROUPS[:admins]])
  end

  context "when there is a redelivering_webhook_event in process" do
    fab!(:redelivering_webhook_event_in_process) do
      Fabricate(
        :redelivering_webhook_event,
        web_hook_event_id: web_hook_event2.id,
        processing: true,
      )
    end

    it "does not delete the webhook event in process" do
      stub_request(:post, web_hook.payload_url).with(
        body: "abc",
        headers: {
          "aa" => 1,
          "bb" => 2,
        },
      ).to_return(status: 400, body: "", headers: {})

      job.execute({})

      expect(RedeliveringWebhookEvent.count).to eq(1)
      expect(
        RedeliveringWebhookEvent.find_by(id: redelivering_webhook_event_in_process.id),
      ).to be_present
    end
  end
end
