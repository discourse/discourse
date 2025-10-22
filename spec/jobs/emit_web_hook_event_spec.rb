# frozen_string_literal: true

require "excon"

RSpec.describe Jobs::EmitWebHookEvent do
  subject(:job) { described_class.new }

  fab!(:post_hook, :web_hook)
  fab!(:inactive_hook, :inactive_web_hook)
  fab!(:post)
  fab!(:user)

  it "raises an error when there is no web hook record" do
    expect { job.execute(event_type: "post", payload: {}) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "raises an error when there is no event type" do
    expect { job.execute(web_hook_id: post_hook.id, payload: {}) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "raises an error when there is no payload" do
    expect { job.execute(web_hook_id: post_hook.id, event_type: "post") }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "should not destroy webhook event in case of error" do
    stub_request(:post, post_hook.payload_url).to_return(status: 500)

    job.execute(
      web_hook_id: post_hook.id,
      payload: { id: post.id }.to_json,
      event_type: WebHookEventType::TYPES[:post_created],
    )

    expect(WebHookEvent.last.web_hook_id).to eq(post_hook.id)
  end

  context "when the web hook is failed" do
    before { SiteSetting.retry_web_hook_events = true }

    context "when the webhook has failed for 404 or 410" do
      before do
        stub_request(:post, post_hook.payload_url).to_return(
          body: "Invalid Access",
          status: response_status,
        )
      end

      let(:response_status) { 410 }

      it "disables the webhook" do
        expect do
          job.execute(
            web_hook_id: post_hook.id,
            event_type: described_class::PING_EVENT,
            retry_count: described_class::MAX_RETRY_COUNT,
          )
        end.to change { post_hook.reload.active }.to(false)
      end

      it "logs webhook deactivation reason" do
        job.execute(
          web_hook_id: post_hook.id,
          event_type: described_class::PING_EVENT,
          retry_count: described_class::MAX_RETRY_COUNT,
        )
        user_history =
          UserHistory.find_by(
            action: UserHistory.actions[:web_hook_deactivate],
            acting_user: Discourse.system_user,
          )
        expect(user_history).to be_present
        expect(user_history.context).to eq(
          ["webhook_id: #{post_hook.id}", "webhook_response_status: #{response_status}"].to_s,
        )
      end
    end

    context "when the webhook has failed" do
      before do
        stub_request(:post, post_hook.payload_url).to_return(body: "Invalid Access", status: 403)
      end

      it "retry if site setting is enabled" do
        expect do
          job.execute(web_hook_id: post_hook.id, event_type: described_class::PING_EVENT)
        end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)
      end

      it "retries at most 5 times" do
        Jobs.run_immediately!

        expect(Jobs::EmitWebHookEvent::MAX_RETRY_COUNT + 1).to eq(5)

        expect do
          job.execute(web_hook_id: post_hook.id, event_type: described_class::PING_EVENT)
        end.to change { WebHookEvent.count }.by(Jobs::EmitWebHookEvent::MAX_RETRY_COUNT + 1)
      end

      it "does not retry for more than maximum allowed times" do
        expect do
          job.execute(
            web_hook_id: post_hook.id,
            event_type: described_class::PING_EVENT,
            retry_count: described_class::MAX_RETRY_COUNT,
          )
        end.to_not change { Jobs::EmitWebHookEvent.jobs.size }
      end

      it "does not retry if site setting is disabled" do
        SiteSetting.retry_web_hook_events = false

        expect do
          job.execute(web_hook_id: post_hook.id, event_type: described_class::PING_EVENT)
        end.not_to change { Jobs::EmitWebHookEvent.jobs.size }
      end

      it "properly logs error on rescue" do
        stub_request(:post, post_hook.payload_url).to_raise("connection error")
        job.execute(web_hook_id: post_hook.id, event_type: described_class::PING_EVENT)

        event = WebHookEvent.last
        expect(event.payload).to eq(MultiJson.dump(ping: "OK"))
        expect(event.status).to eq(-1)
        expect(MultiJson.load(event.response_headers)["error"]).to eq("connection error")
      end
    end
  end

  it "does not raise an error for a ping event without payload" do
    stub_request(:post, post_hook.payload_url).to_return(body: "OK", status: 200)

    job.execute(web_hook_id: post_hook.id, event_type: described_class::PING_EVENT)
  end

  it "doesn't emit when the hook is inactive" do
    job.execute(
      web_hook_id: inactive_hook.id,
      event_type: "post",
      payload: { test: "some payload" }.to_json,
    )
  end

  it "emits normally with sufficient arguments" do
    stub_request(:post, post_hook.payload_url).with(
      body: "{\"post\":{\"test\":\"some payload\"}}",
    ).to_return(body: "OK", status: 200)

    job.execute(
      web_hook_id: post_hook.id,
      event_type: "post",
      payload: { test: "some payload" }.to_json,
    )
  end

  it "doesn't emit if the payload URL resolves to a disallowed IP" do
    FinalDestination::TestHelper.stub_to_fail do
      job.execute(
        web_hook_id: post_hook.id,
        event_type: "post",
        payload: { test: "some payload" }.to_json,
      )
    end
    event = post_hook.web_hook_events.last
    expect(event.response_headers).to eq(
      { error: I18n.t("webhooks.payload_url.blocked_or_internal") }.to_json,
    )
    expect(event.response_body).to eq(nil)
    expect(event.status).to eq(-1)
  end

  context "with category filters" do
    fab!(:category)
    fab!(:topic)
    fab!(:topic_with_category) { Fabricate(:topic, category_id: category.id) }
    fab!(:topic_hook) { Fabricate(:topic_web_hook, categories: [category]) }

    it "doesn't emit when event is not related with defined categories" do
      job.execute(
        web_hook_id: topic_hook.id,
        event_type: "topic",
        category_id: topic.category.id,
        payload: { test: "some payload" }.to_json,
      )
    end

    it "emit when event is related with defined categories" do
      stub_request(:post, post_hook.payload_url).with(
        body: "{\"topic\":{\"test\":\"some payload\"}}",
      ).to_return(body: "OK", status: 200)

      job.execute(
        web_hook_id: topic_hook.id,
        event_type: "topic",
        category_id: topic_with_category.category.id,
        payload: { test: "some payload" }.to_json,
      )
    end
  end

  context "with tag filters" do
    fab!(:tag)
    fab!(:topic) { Fabricate(:topic, tags: [tag]) }
    fab!(:topic_hook) { Fabricate(:topic_web_hook, tags: [tag]) }

    it "doesn't emit when event is not included any tags" do
      job.execute(
        web_hook_id: topic_hook.id,
        event_type: "topic",
        payload: { test: "some payload" }.to_json,
      )
    end

    it "doesn't emit when event is not related with defined tags" do
      job.execute(
        web_hook_id: topic_hook.id,
        event_type: "topic",
        tag_ids: [Fabricate(:tag).id],
        payload: { test: "some payload" }.to_json,
      )
    end

    it "emit when event is related with defined tags" do
      stub_request(:post, post_hook.payload_url).with(
        body: "{\"topic\":{\"test\":\"some payload\"}}",
      ).to_return(body: "OK", status: 200)

      job.execute(
        web_hook_id: topic_hook.id,
        event_type: "topic",
        tag_ids: topic.tags.pluck(:id),
        payload: { test: "some payload" }.to_json,
      )
    end
  end

  context "with group filters" do
    fab!(:group)
    fab!(:user) { Fabricate(:user, groups: [group]) }
    fab!(:like_hook) { Fabricate(:like_web_hook, groups: [group]) }

    it "doesn't emit when event is not included any groups" do
      job.execute(
        web_hook_id: like_hook.id,
        event_type: "like",
        payload: { test: "some payload" }.to_json,
      )
    end

    it "doesn't emit when event is not related with defined groups" do
      job.execute(
        web_hook_id: like_hook.id,
        event_type: "like",
        group_ids: [Fabricate(:group).id],
        payload: { test: "some payload" }.to_json,
      )
    end

    it "emit when event is related with defined groups" do
      stub_request(:post, like_hook.payload_url).with(
        body: "{\"like\":{\"test\":\"some payload\"}}",
      ).to_return(body: "OK", status: 200)

      job.execute(
        web_hook_id: like_hook.id,
        event_type: "like",
        group_ids: user.groups.pluck(:id),
        payload: { test: "some payload" }.to_json,
      )
    end
  end

  describe "#send_webhook!" do
    it "creates delivery event record" do
      stub_request(:post, post_hook.payload_url).to_return(body: "OK", status: 200)

      topic_event_type = WebHookEventType.all.first
      web_hook_id = Fabricate("#{topic_event_type.name.gsub("_created", "")}_web_hook").id

      expect do
        job.execute(
          web_hook_id: web_hook_id,
          event_type: topic_event_type.name,
          payload: { test: "some payload" }.to_json,
        )
      end.to change(WebHookEvent, :count).by(1)
    end

    it "sets up proper request headers" do
      stub_request(:post, post_hook.payload_url).to_return(
        headers: {
          test: "string",
        },
        body: "OK",
        status: 200,
      )

      job.execute(
        web_hook_id: post_hook.id,
        event_type: described_class::PING_EVENT,
        event_name: described_class::PING_EVENT,
        payload: { test: "this payload shouldn't appear" }.to_json,
      )

      event = WebHookEvent.last
      headers = MultiJson.load(event.headers)
      expect(headers["Content-Length"]).to eq("13")
      expect(headers["Host"]).to eq("meta.discourse.org")
      expect(headers["X-Discourse-Event-Id"]).to eq(event.id.to_s)
      expect(headers["X-Discourse-Event-Type"]).to eq(described_class::PING_EVENT)
      expect(headers["X-Discourse-Event"]).to eq(described_class::PING_EVENT)
      expect(headers["X-Discourse-Event-Signature"]).to eq(
        "sha256=162f107f6b5022353274eb1a7197885cfd35744d8d08e5bcea025d309386b7d6",
      )
      expect(event.payload).to eq(MultiJson.dump(ping: "OK"))
      expect(event.status).to eq(200)
      expect(MultiJson.load(event.response_headers)["test"]).to eq("string")
      expect(event.response_body).to eq("OK")
    end

    it "sets up proper request headers when an error raised" do
      stub_request(:post, post_hook.payload_url).to_raise("error")

      job.execute(
        web_hook_id: post_hook.id,
        event_type: described_class::PING_EVENT,
        event_name: described_class::PING_EVENT,
        payload: { test: "this payload shouldn't appear" }.to_json,
      )

      event = WebHookEvent.last
      headers = MultiJson.load(event.headers)
      expect(headers["Content-Length"]).to eq("13")
      expect(headers["Host"]).to eq("meta.discourse.org")
      expect(headers["X-Discourse-Event-Id"]).to eq(event.id.to_s)
      expect(headers["X-Discourse-Event-Type"]).to eq(described_class::PING_EVENT)
      expect(headers["X-Discourse-Event"]).to eq(described_class::PING_EVENT)
      expect(headers["X-Discourse-Event-Signature"]).to eq(
        "sha256=162f107f6b5022353274eb1a7197885cfd35744d8d08e5bcea025d309386b7d6",
      )
      expect(event.payload).to eq(MultiJson.dump(ping: "OK"))
    end

    context "with `webhook_event_headers` modifier" do
      let(:modifier_block) do
        Proc.new do |headers, _, _|
          headers["D-Test-Woo"] = "xyz"
          headers
        end
      end
      it "Allows for header modifications" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:web_hook_event_headers, &modifier_block)

        stub_request(:post, post_hook.payload_url).to_return(body: "OK", status: 200)

        topic_event_type = WebHookEventType.all.first
        web_hook_id = Fabricate("#{topic_event_type.name.gsub("_created", "")}_web_hook").id

        job.execute(
          web_hook_id: web_hook_id,
          event_type: topic_event_type.name,
          payload: { test: "some payload" }.to_json,
        )
        webhook_event = WebHookEvent.last
        expect(JSON.parse(webhook_event.headers)).to include("D-Test-Woo" => "xyz")
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :web_hook_event_headers,
          &modifier_block
        )
      end
    end
  end
end
