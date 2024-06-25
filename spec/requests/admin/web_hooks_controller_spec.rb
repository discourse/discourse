# frozen_string_literal: true

RSpec.describe Admin::WebHooksController do
  fab!(:web_hook)
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#create" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "creates a webhook" do
        post "/admin/api/web_hooks.json",
             params: {
               web_hook: {
                 payload_url: "https://meta.discourse.org/",
                 content_type: 1,
                 secret: "a_secret_for_webhooks",
                 wildcard_web_hook: false,
                 active: true,
                 verify_certificate: true,
                 web_hook_event_type_ids: [WebHookEventType::TYPES[:topic_created]],
                 group_ids: [],
                 category_ids: [],
               },
             }

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["web_hook"]["payload_url"]).to eq("https://meta.discourse.org/")
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:web_hook_create],
          ).count,
        ).to eq(1)
      end

      it "returns error when field is not filled correctly" do
        post "/admin/api/web_hooks.json",
             params: {
               web_hook: {
                 content_type: 1,
                 secret: "a_secret_for_webhooks",
                 wildcard_web_hook: false,
                 active: true,
                 verify_certificate: true,
                 web_hook_event_type_ids: [WebHookEventType::TYPES[:topic_created]],
                 group_ids: [],
                 category_ids: [],
               },
             }

        expect(response.status).to eq(422)
        response_body = response.parsed_body

        expect(response_body["errors"]).to be_present
      end
    end

    shared_examples "webhook creation not allowed" do
      it "prevents creation with a 404 response" do
        post "/admin/api/web_hooks.json",
             params: {
               web_hook: {
                 payload_url: "https://meta.discourse.org/",
                 content_type: 1,
                 secret: "a_secret_for_webhooks",
                 wildcard_web_hook: false,
                 active: true,
                 verify_certificate: true,
                 web_hook_event_type_ids: [1],
                 group_ids: [],
                 category_ids: [],
               },
             }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["web_hook"]).to be_nil
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "webhook creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "webhook creation not allowed"
    end
  end

  describe "#update" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "logs webhook update" do
        put "/admin/api/web_hooks/#{web_hook.id}.json",
            params: {
              web_hook: {
                active: false,
                payload_url: "https://test.com",
              },
            }

        expect(response.status).to eq(200)
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:web_hook_update],
            new_value: "active: false, payload_url: https://test.com",
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "webhook update not allowed" do
      it "prevents updates with a 404 response" do
        current_payload_url = web_hook.payload_url
        put "/admin/api/web_hooks/#{web_hook.id}.json",
            params: {
              web_hook: {
                active: false,
                payload_url: "https://test.com",
              },
            }

        web_hook.reload
        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(web_hook.payload_url).to eq(current_payload_url)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "webhook update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "webhook update not allowed"
    end
  end

  describe "#destroy" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "logs webhook destroy" do
        delete "/admin/api/web_hooks/#{web_hook.id}.json",
               params: {
                 web_hook: {
                   active: false,
                   payload_url: "https://test.com",
                 },
               }

        expect(response.status).to eq(200)
        expect(
          UserHistory.where(
            acting_user_id: admin.id,
            action: UserHistory.actions[:web_hook_destroy],
          ).exists?,
        ).to eq(true)
      end
    end

    shared_examples "webhook deletion not allowed" do
      it "prevents deletion with a 404 response" do
        delete "/admin/api/web_hooks/#{web_hook.id}.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(web_hook.reload).to be_present
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "webhook deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "webhook deletion not allowed"
    end
  end

  describe "#list_events" do
    fab!(:web_hook_event1) { Fabricate(:web_hook_event, web_hook: web_hook, id: 1, status: 200) }
    fab!(:web_hook_event2) { Fabricate(:web_hook_event, web_hook: web_hook, id: 2, status: 404) }

    before { sign_in(admin) }

    context "when status param is provided" do
      it "load_more_web_hook_events URL is correct" do
        get "/admin/api/web_hook_events/#{web_hook.id}.json", params: { status: "successful" }
        expect(response.parsed_body["load_more_web_hook_events"]).to include("status=successful")
      end
    end

    context "when status is 'successful'" do
      it "lists the successfully delivered webhook events" do
        get "/admin/api/web_hook_events/#{web_hook.id}.json", params: { status: "successful" }
        expect(response.parsed_body["web_hook_events"].map { |c| c["id"] }).to eq(
          [web_hook_event1.id],
        )
      end
    end

    context "when status is 'failed'" do
      it "lists the failed webhook events" do
        get "/admin/api/web_hook_events/#{web_hook.id}.json", params: { status: "failed" }
        expect(response.parsed_body["web_hook_events"].map { |c| c["id"] }).to eq(
          [web_hook_event2.id],
        )
      end
    end

    context "when there is no status param" do
      it "lists all webhook events" do
        get "/admin/api/web_hook_events/#{web_hook.id}.json"
        expect(response.parsed_body["web_hook_events"].map { |c| c["id"] }).to match_array(
          [web_hook_event1.id, web_hook_event2.id],
        )
      end
    end
  end

  describe "#ping" do
    context "when logged in as admin" do
      before { sign_in(admin) }

      it "enqueues the ping event" do
        expect do post "/admin/api/web_hooks/#{web_hook.id}/ping.json" end.to change {
          Jobs::EmitWebHookEvent.jobs.size
        }.by(1)

        expect(response.status).to eq(200)
        job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first
        expect(job_args["web_hook_id"]).to eq(web_hook.id)
        expect(job_args["event_type"]).to eq("ping")
      end
    end

    shared_examples "webhook ping not allowed" do
      it "fails to enqueue a ping with 404 response" do
        expect do post "/admin/api/web_hooks/#{web_hook.id}/ping.json" end.not_to change {
          Jobs::EmitWebHookEvent.jobs.size
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "webhook ping not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "webhook ping not allowed"
    end
  end

  describe "#redeliver_event" do
    let!(:web_hook_event) do
      WebHookEvent.create!(web_hook: web_hook, payload: "abc", headers: JSON.dump(aa: "1", bb: "2"))
    end

    before { sign_in(admin) }

    it "emits the web hook and updates the response headers and body" do
      stub_request(:post, web_hook.payload_url).with(
        body: "abc",
        headers: {
          "aa" => 1,
          "bb" => 2,
        },
      ).to_return(
        status: 402,
        body: "efg",
        headers: {
          "Content-Type" => "application/json",
          "yoo" => "man",
        },
      )
      post "/admin/api/web_hooks/#{web_hook.id}/events/#{web_hook_event.id}/redeliver.json"
      expect(response.status).to eq(200)

      parsed_event = response.parsed_body["web_hook_event"]
      expect(parsed_event["id"]).to eq(web_hook_event.id)
      expect(parsed_event["status"]).to eq(402)

      expect(JSON.parse(parsed_event["headers"])).to eq({ "aa" => "1", "bb" => "2" })
      expect(parsed_event["payload"]).to eq("abc")

      expect(JSON.parse(parsed_event["response_headers"])).to eq(
        { "content-type" => "application/json", "yoo" => "man" },
      )
      expect(parsed_event["response_body"]).to eq("efg")
    end

    it "doesn't emit the web hook if the payload URL resolves to an internal IP" do
      FinalDestination::TestHelper.stub_to_fail do
        post "/admin/api/web_hooks/#{web_hook.id}/events/#{web_hook_event.id}/redeliver.json"
      end
      expect(response.status).to eq(200)

      parsed_event = response.parsed_body["web_hook_event"]
      expect(parsed_event["id"]).to eq(web_hook_event.id)
      expect(parsed_event["response_headers"]).to eq(
        { error: I18n.t("webhooks.payload_url.blocked_or_internal") }.to_json,
      )
      expect(parsed_event["status"]).to eq(-1)
      expect(parsed_event["response_body"]).to eq(nil)
    end

    context "with web_hook_event_headers_for_redelivery modifier registered" do
      let(:modifier_block) do
        Proc.new do |headers, _, _|
          headers["bb"] = "22"
          headers
        end
      end
      it "modifies the headers & saves the updated headers to the webhook event" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:web_hook_event_headers, &modifier_block)

        stub_request(:post, web_hook.payload_url).to_return(
          status: 402,
          body: "efg",
          headers: {
            "Content-Type" => "application/json",
            "yoo" => "man",
          },
        )
        post "/admin/api/web_hooks/#{web_hook.id}/events/#{web_hook_event.id}/redeliver.json"
        expect(response.status).to eq(200)

        expect(JSON.parse(web_hook_event.reload.headers)).to eq({ "aa" => "1", "bb" => "22" })
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
