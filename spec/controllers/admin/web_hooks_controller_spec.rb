require "rails_helper"

describe Admin::WebHooksController do

  it 'is a subclass of AdminController' do
    expect(Admin::WebHooksController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end
    let(:web_hook) { Fabricate(:web_hook) }

    describe '#create' do
      it 'creates a webhook' do
        post :create, params: {
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
        }, format: :json

        expect(response).to be_success

        json = ::JSON.parse(response.body)
        expect(json["web_hook"]["payload_url"]).to be_present
      end

      it 'returns error when field is not filled correctly' do
        post :create, params: {
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
        }, format: :json

        expect(response.status).to eq 422
        response_body = JSON.parse(response.body)

        expect(response_body["errors"]).to be_present
      end
    end

    describe '#ping' do
      it 'enqueues the ping event' do
        Jobs.expects(:enqueue)
          .with(:emit_web_hook_event, web_hook_id: web_hook.id, event_type: 'ping', event_name: 'ping')

        post :ping, params: { id: web_hook.id }, format: :json

        expect(response).to be_success
      end
    end
  end
end
