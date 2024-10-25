# frozen_string_literal: true

describe Chat::Api::CurrentUserThreadsController do
  fab!(:current_user) { Fabricate(:user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    sign_in(current_user)
  end

  describe "#index" do
    describe "success" do
      let!(:thread) do
        Fabricate(
          :chat_thread,
          original_message_user: current_user,
          with_replies: 2,
          use_service: true,
        )
      end

      it "works" do
        get "/chat/api/me/threads"

        expect(response).to have_http_status :ok
        expect(response.parsed_body[:threads]).not_to be_empty
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
end
