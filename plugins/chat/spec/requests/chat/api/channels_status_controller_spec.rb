# frozen_string_literal: true

RSpec.describe Chat::Api::ChannelsStatusController do
  fab!(:channel_1) { Fabricate(:category_channel, status: :open) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  def status(status)
    { status: status }
  end

  describe "#update" do
    context "when user is not staff" do
      before { sign_in(Fabricate(:user)) }

      it "returns an error" do
        put "/chat/api/channels/#{channel_1.id}/status", params: status("closed")

        expect(response.status).to eq(403)
      end
    end

    context "when user is admin" do
      before { sign_in(Fabricate(:admin)) }

      context "when channel doesn’t exist" do
        before { channel_1.destroy! }

        it "returns an error" do
          put "/chat/api/channels/#{channel_1.id}/status", params: status("closed")

          expect(response.status).to eq(404)
        end
      end

      context "when channel is in read-only" do
        before { channel_1.update!(status: "read_only") }

        it "returns an error" do
          put "/chat/api/channels/#{channel_1.id}/status", params: status("closed")

          expect(response.status).to eq(403)
        end
      end

      context "when channel is archived" do
        before { channel_1.update!(status: "archived") }

        it "returns an error" do
          put "/chat/api/channels/#{channel_1.id}/status", params: status("closed")

          expect(response.status).to eq(403)
        end
      end

      context "when changing from open to closed" do
        it "changes the status" do
          expect {
            put "/chat/api/channels/#{channel_1.id}/status", params: status("closed")
          }.to change { channel_1.reload.status }.to("closed").from("open")

          expect(response.status).to eq(200)
          channel = response.parsed_body["channel"]
          expect(channel["id"]).to eq(channel_1.id)
        end
      end

      context "when changing from closed to open" do
        before { channel_1.update!(status: "closed") }

        it "changes the status" do
          expect {
            put "/chat/api/channels/#{channel_1.id}/status", params: status("open")
          }.to change { channel_1.reload.status }.to("open").from("closed")

          expect(response.status).to eq(200)
          channel = response.parsed_body["channel"]
          expect(channel["id"]).to eq(channel_1.id)
        end
      end
    end
  end
end
