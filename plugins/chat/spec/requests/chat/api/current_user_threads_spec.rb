# frozen_string_literal: true

require "rails_helper"

describe Chat::Api::CurrentUserThreadsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#index" do
    describe "success" do
      it "works" do
        get "/chat/api/me/threads"

        expect(response.status).to eq(200)
      end
    end

    context "when threads are not found" do
      it "returns a 200 with empty threads" do
        get "/chat/api/me/threads"

        expect(response.status).to eq(200)
        expect(response.parsed_body["threads"]).to eq([])
      end
    end
  end

  describe "#thread_count" do
    describe "success" do
      it "works" do
        get "/chat/api/me/threads/count"

        expect(response.status).to eq(200)
      end
    end

    context "when threads are not found" do
      it "returns a 200 when there are no threads" do
        get "/chat/api/me/threads/count"

        expect(response.status).to eq(200)
        expect(response.parsed_body["thread_count"]).to eq(0)
      end
    end
  end
end
