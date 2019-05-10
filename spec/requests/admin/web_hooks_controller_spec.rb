# frozen_string_literal: true

require "rails_helper"

describe Admin::WebHooksController do

  it 'is a subclass of AdminController' do
    expect(Admin::WebHooksController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:web_hook) { Fabricate(:web_hook) }
    fab!(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#create' do
      it 'creates a webhook' do
        post "/admin/api/web_hooks.json", params: {
          web_hook: {
            payload_url: 'https://meta.discourse.org/',
            content_type: 1,
            secret: "a_secret_for_webhooks",
            wildcard_web_hook: false,
            active: true,
            verify_certificate: true,
            web_hook_event_type_ids: [1],
            group_ids: [],
            category_ids: []
          }
        }

        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)
        expect(json["web_hook"]["payload_url"]).to eq("https://meta.discourse.org/")
        expect(UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:web_hook_create]).count).to eq(1)
      end

      it 'returns error when field is not filled correctly' do
        post "/admin/api/web_hooks.json", params: {
          web_hook: {
            content_type: 1,
            secret: "a_secret_for_webhooks",
            wildcard_web_hook: false,
            active: true,
            verify_certificate: true,
            web_hook_event_type_ids: [1],
            group_ids: [],
            category_ids: []
          }
        }

        expect(response.status).to eq(422)
        response_body = JSON.parse(response.body)

        expect(response_body["errors"]).to be_present
      end
    end

    describe '#update' do
      it "logs webhook update" do
        put "/admin/api/web_hooks/#{web_hook.id}.json", params: {
          web_hook: { active: false, payload_url: "https://test.com" }
        }

        expect(response.status).to eq(200)
        expect(UserHistory.where(acting_user_id: admin.id,
                                 action: UserHistory.actions[:web_hook_update],
                                 new_value: "payload_url: https://test.com, active: false").exists?).to eq(true)
      end
    end

    describe '#destroy' do
      it "logs webhook destroy" do
        delete "/admin/api/web_hooks/#{web_hook.id}.json", params: {
          web_hook: { active: false, payload_url: "https://test.com" }
        }

        expect(response.status).to eq(200)
        expect(UserHistory.where(acting_user_id: admin.id, action: UserHistory.actions[:web_hook_destroy]).exists?).to eq(true)
      end
    end

    describe '#ping' do
      it 'enqueues the ping event' do
        expect do
          post "/admin/api/web_hooks/#{web_hook.id}/ping.json"
        end.to change { Jobs::EmitWebHookEvent.jobs.size }.by(1)

        expect(response.status).to eq(200)
        job_args = Jobs::EmitWebHookEvent.jobs.first["args"].first
        expect(job_args["web_hook_id"]).to eq(web_hook.id)
        expect(job_args["event_type"]).to eq("ping")
      end
    end
  end
end
