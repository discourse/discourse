# frozen_string_literal: true

describe Chat::Api::CurrentUserChannelsController do
  fab!(:current_user, :user)

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    context "as anonymous user" do
      it "returns an error" do
        get "/chat/api/me/channels"
        expect(response.status).to eq(403)
      end
    end

    context "as disallowed user" do
      before do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(Fabricate(:user))
      end

      it "returns an error" do
        get "/chat/api/me/channels"

        expect(response.status).to eq(403)
      end
    end

    context "as allowed user" do
      fab!(:current_user, :user)

      before { sign_in(current_user) }

      it "returns public channels with memberships" do
        channel = Fabricate(:category_channel)
        channel.add(current_user)
        get "/chat/api/me/channels"

        expect(response.parsed_body["public_channels"][0]["id"]).to eq(channel.id)
      end

      context "with multiple direct messages" do
        fab!(:user_1, :user)
        fab!(:user_2, :user)
        fab!(:dm_channel_1, :direct_message)

        fab!(:direct_message_channel_1) do
          Fabricate(:direct_message_channel, chatable: dm_channel_1)
        end

        it "avoids N+1 queries with user custom fields" do
          custom_field_name = "#{Time.now.to_i}_custom_field"
          SiteSetting.public_user_custom_fields = custom_field_name

          Fabricate(
            :user_chat_channel_membership_for_dm,
            chat_channel: direct_message_channel_1,
            user: user_1,
            following: true,
          )

          Chat::DirectMessageUser.create!(direct_message: dm_channel_1, user: user_1)
          Chat::DirectMessageUser.create!(direct_message: dm_channel_1, user: user_2)

          sign_in(user_1)

          queries =
            track_sql_queries do
              get "/chat/api/me/channels"

              expect(response.status).to eq(200)
            end

          expect(
            queries.count { |q| q.include?("user_custom_fields") && q.include?(custom_field_name) },
          ).to eq(1)
        end
      end

      context "with multiple channels and category group moderation" do
        fab!(:group)
        fab!(:channel_1, :category_channel)
        fab!(:channel_2, :category_channel)
        fab!(:channel_3, :category_channel)

        before do
          SiteSetting.enable_category_group_moderation = true
          group.add(current_user)
          channel_1.add(current_user)
          channel_2.add(current_user)
          channel_3.add(current_user)

          # Make one channel have group moderation
          channel_2.chatable.category_moderation_groups.create!(group:)
        end

        it "avoids N+1 queries for category group moderator checks" do
          queries =
            track_sql_queries do
              get "/chat/api/me/channels"
              expect(response.status).to eq(200)
            end

          category_moderation_queries =
            queries.count do |query|
              query.include?("category_moderation_groups") && query.include?("group_users")
            end

          expect(category_moderation_queries).to be <= 1
        end
      end
    end
  end
end
