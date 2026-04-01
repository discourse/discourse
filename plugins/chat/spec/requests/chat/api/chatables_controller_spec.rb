# frozen_string_literal: true

RSpec.describe Chat::Api::ChatablesController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  fab!(:current_user, :user)

  describe "#index" do
    describe "without chat permissions" do
      it "errors errors for anon" do
        get "/chat/api/chatables"

        expect(response.status).to eq(403)
      end

      it "errors when user cannot chat" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(current_user)

        get "/chat/api/chatables"

        expect(response.status).to eq(403)
      end
    end

    describe "with chat permissions" do
      fab!(:channel_1, :chat_channel)

      before { channel_1.add(current_user) }

      it "returns results" do
        sign_in(current_user)

        get "/chat/api/chatables", params: { term: channel_1.name }

        expect(response.status).to eq(200)
        expect(response.parsed_body["category_channels"][0]["identifier"]).to eq(
          "c-#{channel_1.id}",
        )
      end
    end

    describe "excluded_memberships_channel_id" do
      fab!(:target_user, :user)
      fab!(:private_dm_channel) do
        Fabricate(:direct_message_channel, users: [Fabricate(:user), target_user])
      end

      let(:base_params) do
        {
          term: target_user.username,
          include_users: true,
          include_groups: false,
          include_category_channels: false,
          include_direct_message_channels: false,
        }
      end

      before do
        SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
        sign_in(current_user)
      end

      it "does not apply the exclusion filter when the user cannot access the channel" do
        get "/chat/api/chatables",
            params: base_params.merge(excluded_memberships_channel_id: private_dm_channel.id)

        expect(response.status).to eq(200)
        identifiers = response.parsed_body["users"].map { |u| u["identifier"] }
        expect(identifiers).to include("u-#{target_user.id}")
      end

      it "does not apply the exclusion filter for a non-existent channel" do
        get "/chat/api/chatables", params: base_params.merge(excluded_memberships_channel_id: -1)

        expect(response.status).to eq(200)
        identifiers = response.parsed_body["users"].map { |u| u["identifier"] }
        expect(identifiers).to include("u-#{target_user.id}")
      end

      it "applies the exclusion filter when the user can access the channel" do
        accessible_dm_channel =
          Fabricate(:direct_message_channel, users: [current_user, target_user])

        get "/chat/api/chatables",
            params: base_params.merge(excluded_memberships_channel_id: accessible_dm_channel.id)

        expect(response.status).to eq(200)
        identifiers = response.parsed_body["users"].map { |u| u["identifier"] }
        expect(identifiers).not_to include("u-#{target_user.id}")
      end
    end
  end
end
