# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChatChannelThreadsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.enable_experimental_chat_threaded_discussions = true
    Group.refresh_automatic_groups!
    sign_in(current_user)
  end

  describe "show" do
    context "when thread does not exist" do
      fab!(:thread) { Fabricate(:chat_thread, original_message: Fabricate(:chat_message)) }

      it "returns 404" do
        thread.destroy!
        get "/chat/api/threads/#{thread.id}"
        expect(response.status).to eq(404)
      end
    end

    context "when thread exists" do
      fab!(:thread) { Fabricate(:chat_thread, original_message: Fabricate(:chat_message)) }

      it "works" do
        get "/chat/api/threads/#{thread.id}"
        expect(response.status).to eq(200)
        expect(response.parsed_body["thread"]["id"]).to eq(thread.id)
      end

      context "when enable_experimental_chat_threaded_discussions is disabled" do
        before { SiteSetting.enable_experimental_chat_threaded_discussions = false }

        it "returns 404" do
          get "/chat/api/threads/#{thread.id}"
          expect(response.status).to eq(404)
        end
      end

      context "when user cannot access the channel" do
        before do
          thread.channel.update!(chatable: Fabricate(:private_category, group: Fabricate(:group)))
        end

        it "returns 403" do
          get "/chat/api/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end

      context "when user cannot chat" do
        before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_4] }

        it "returns 403" do
          get "/chat/api/threads/#{thread.id}"
          expect(response.status).to eq(403)
        end
      end
    end
  end
end
