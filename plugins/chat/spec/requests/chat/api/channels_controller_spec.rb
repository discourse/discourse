# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Api::ChannelsController do
  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    context "as anonymous user" do
      it "returns an error" do
        get "/chat/api/channels"

        expect(response.status).to eq(403)
      end
    end

    context "as disallowed user" do
      fab!(:current_user) { Fabricate(:user) }

      before do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
        sign_in(current_user)
      end

      it "returns an error" do
        get "/chat/api/channels"

        expect(response.status).to eq(403)
      end
    end

    context "as allowed user" do
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      context "with category channels" do
        context "when channel is public" do
          fab!(:channel_1) { Fabricate(:category_channel) }

          it "returns the channel" do
            get "/chat/api/channels"

            expect(response.status).to eq(200)
            expect(response.parsed_body["channels"].map { |channel| channel["id"] }).to eq(
              [channel_1.id],
            )
          end

          context "when chatable is destroyed" do
            before { channel_1.chatable.destroy! }

            it "returns nothing" do
              get "/chat/api/channels"

              expect(response.status).to eq(200)
              expect(response.parsed_body["channels"]).to be_blank
            end
          end
        end

        context "when channel has limited access" do
          fab!(:group_1) { Fabricate(:group) }
          fab!(:channel_1) { Fabricate(:private_category_channel, group: group_1) }

          context "when user has access" do
            before { group_1.add(current_user) }

            it "returns the channel" do
              get "/chat/api/channels"

              expect(response.status).to eq(200)
              expect(response.parsed_body["channels"].map { |channel| channel["id"] }).to eq(
                [channel_1.id],
              )
            end
          end

          context "when user has no access" do
            it "returns nothing" do
              get "/chat/api/channels"

              expect(response.status).to eq(200)
              expect(response.parsed_body["channels"]).to be_blank
            end

            context "when user is admin" do
              before { sign_in(Fabricate(:admin)) }

              it "returns the channels" do
                get "/chat/api/channels"

                expect(response.status).to eq(200)
                expect(response.parsed_body["channels"].map { |channel| channel["id"] }).to eq(
                  [channel_1.id],
                )
              end
            end
          end
        end
      end

      context "with direct message channels" do
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

        it "doesnt return direct message channels" do
          get "/chat/api/channels"
          expect(response.parsed_body["channels"]).to be_blank
        end
      end
    end
  end

  describe "#show" do
    context "when anonymous" do
      it "returns an error" do
        get "/chat/api/channels/-999"

        expect(response.status).to eq(403)
      end
    end

    context "when user cannot access channel" do
      fab!(:channel_1) { Fabricate(:private_category_channel) }

      before { sign_in(Fabricate(:user)) }

      it "returns an error" do
        get "/chat/api/channels/#{channel_1.id}"

        expect(response.status).to eq(403)
      end
    end

    context "when user can access channel" do
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      context "when channel doesn’t exist" do
        it "returns an error" do
          get "/chat/api/channels/-999"

          expect(response.status).to eq(404)
        end
      end

      context "when channel exists" do
        fab!(:channel_1) { Fabricate(:category_channel) }

        it "can find channel by id" do
          get "/chat/api/channels/#{channel_1.id}"

          expect(response.status).to eq(200)
          expect(response.parsed_body.dig("channel", "id")).to eq(channel_1.id)
        end
      end
    end
  end

  describe "#destroy" do
    fab!(:channel_1) { Fabricate(:category_channel) }

    context "when user is not staff" do
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      it "returns an error" do
        delete "/chat/api/channels/#{channel_1.id}"

        expect(response.status).to eq(403)
      end
    end

    context "when user is admin" do
      fab!(:current_user) { Fabricate(:admin) }

      before { sign_in(current_user) }

      context "when the channel doesn’t exist" do
        before { channel_1.destroy! }

        it "returns an error" do
          delete "/chat/api/channels/#{channel_1.id}"

          expect(response.status).to eq(404)
        end
      end

      context "with valid params" do
        it "properly destroys the channel" do
          delete "/chat/api/channels/#{channel_1.id}"

          expect(response.status).to eq(200)
          expect(channel_1.reload.trashed?).to eq(true)
          expect(
            job_enqueued?(job: Jobs::Chat::ChannelDelete, args: { chat_channel_id: channel_1.id }),
          ).to eq(true)
          expect(
            UserHistory.exists?(
              acting_user_id: current_user.id,
              action: UserHistory.actions[:custom_staff],
              custom_type: "chat_channel_delete",
            ),
          ).to eq(true)
        end

        it "generates a valid new slug to prevent collisions" do
          SiteSetting.max_topic_title_length = 20
          channel_1 = Fabricate(:chat_channel, name: "a" * SiteSetting.max_topic_title_length)
          freeze_time(DateTime.parse("2022-07-08 09:30:00"))
          old_slug = channel_1.slug

          delete "/chat/api/channels/#{channel_1.id}"

          expect(response.status).to eq(200)
          expect(channel_1.reload.slug).to eq(
            "20220708-0930-#{old_slug}-deleted".truncate(
              SiteSetting.max_topic_title_length,
              omission: "",
            ),
          )
        end
      end
    end
  end

  describe "#create" do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:category) { Fabricate(:category) }

    let(:params) do
      {
        channel: {
          type: category.class.name,
          chatable_id: category.id,
          name: "channel name",
          description: "My new channel",
          threading_enabled: false,
        },
      }
    end

    before { sign_in(admin) }

    it "creates a channel associated to a category" do
      post "/chat/api/channels", params: params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.name).to eq(params[:channel][:name])
      expect(new_channel.slug).to eq("channel-name")
      expect(new_channel.description).to eq(params[:channel][:description])
      expect(new_channel.chatable_type).to eq(category.class.name)
      expect(new_channel.chatable_id).to eq(category.id)
    end

    it "creates a channel using the user-provided slug" do
      new_params = params.dup
      new_params[:channel][:slug] = "wow-so-cool"
      post "/chat/api/channels", params: new_params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.slug).to eq("wow-so-cool")
    end

    context "when the user-provided slug already exists for a channel" do
      before do
        params[:channel][:slug] = "wow-so-cool"
        post "/chat/api/channels", params: params
        params[:channel][:name] = "new name"
      end

      it "returns an error" do
        post "/chat/api/channels", params: params
        expect(response).to have_http_status :unprocessable_entity
      end
    end

    it "creates a channel sets auto_join_users to false by default" do
      post "/chat/api/channels", params: params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.auto_join_users).to eq(false)
    end

    it "creates a channel with auto_join_users set to true" do
      params[:channel][:auto_join_users] = true
      post "/chat/api/channels", params: params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.auto_join_users).to eq(true)
    end

    it "creates a channel sets threading_enabled to false by default" do
      post "/chat/api/channels", params: params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.threading_enabled).to eq(false)
    end

    it "creates a channel with threading_enabled set to true" do
      params[:channel][:threading_enabled] = true
      post "/chat/api/channels", params: params
      expect(response.status).to eq(200)

      new_channel = Chat::Channel.find(response.parsed_body.dig("channel", "id"))

      expect(new_channel.threading_enabled).to eq(true)
    end

    describe "triggers the auto-join process" do
      fab!(:chatters_group) { Fabricate(:group) }
      fab!(:user) { Fabricate(:user, last_seen_at: 15.minute.ago) }

      before do
        Jobs.run_immediately!
        Fabricate(:category_group, category: category, group: chatters_group)
        chatters_group.add(user)
      end

      it "joins the user when auto_join_users is true" do
        params[:channel][:auto_join_users] = true
        post "/chat/api/channels", params: params
        expect(response.status).to eq(200)

        created_channel_id = response.parsed_body.dig("channel", "id")
        membership_exists =
          Chat::UserChatChannelMembership.find_by(
            user: user,
            chat_channel_id: created_channel_id,
            following: true,
          )

        expect(membership_exists).to be_present
      end

      it "doesn't join the user when auto_join_users is false" do
        params[:channel][:auto_join_users] = false
        post "/chat/api/channels", params: params
        expect(response.status).to eq(200)

        created_channel_id = response.parsed_body.dig("channel", "id")
        membership_exists =
          Chat::UserChatChannelMembership.find_by(
            user: user,
            chat_channel_id: created_channel_id,
            following: true,
          )

        expect(membership_exists).to be_nil
      end
    end
  end

  describe "#update" do
    include_examples "channel access example", :put

    context "when user can’t edit channel" do
      fab!(:channel) { Fabricate(:category_channel) }

      before { sign_in(Fabricate(:user)) }

      it "returns a 403" do
        put "/chat/api/channels/#{channel.id}",
            params: {
              channel: {
                name: "joffrey",
                description: "cat owner",
              },
            }

        expect(response.status).to eq(403)
      end
    end

    context "when user provided invalid params" do
      fab!(:channel) { Fabricate(:category_channel, user_count: 10) }

      before { sign_in(Fabricate(:admin)) }

      it "doesn’t change invalid properties" do
        put "/chat/api/channels/#{channel.id}", params: { user_count: 40 }

        expect(channel.reload.user_count).to eq(10)
      end
    end

    context "when user provided an empty name" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:channel) do
        Fabricate(:category_channel, name: "something", description: "something else")
      end

      before { sign_in(user) }

      it "nullifies the field and doesn’t store an empty string" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { name: "  " } }

        expect(channel.reload.name).to eq(nil)
      end

      it "doesn’t nullify the description" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { name: "  " } }

        expect(channel.reload.description).to eq("something else")
      end
    end

    context "when user provides an empty description" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:channel) do
        Fabricate(:category_channel, name: "something else", description: "something")
      end

      before { sign_in(user) }

      it "nullifies the field and doesn’t store an empty string" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { description: "  " } }

        expect(channel.reload.description).to eq(nil)
      end

      it "doesn’t nullify the name" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { description: "  " } }

        expect(channel.reload.name).to eq("something else")
      end
    end

    context "when user provides an empty slug" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:channel) do
        Fabricate(:category_channel, name: "something else", description: "something")
      end

      before { sign_in(user) }

      it "does not nullify the slug" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { slug: " " } }

        expect(channel.reload.slug).to eq("something-else")
      end
    end

    context "when channel is a direct message channel" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:channel) { Fabricate(:direct_message_channel) }

      before { sign_in(user) }

      it "raises a 403" do
        put "/chat/api/channels/#{channel.id}"

        expect(response.status).to eq(403)
      end
    end

    context "when user provides valid params" do
      fab!(:user) { Fabricate(:admin) }
      fab!(:channel) { Fabricate(:category_channel) }

      before { sign_in(user) }

      it "sets properties" do
        put "/chat/api/channels/#{channel.id}",
            params: {
              channel: {
                name: "joffrey",
                slug: "cat-king",
                description: "cat owner",
              },
            }

        expect(channel.reload.name).to eq("joffrey")
        expect(channel.reload.slug).to eq("cat-king")
        expect(channel.reload.description).to eq("cat owner")
      end

      it "publishes an update" do
        messages =
          MessageBus.track_publish("/chat/channel-edits") do
            put "/chat/api/channels/#{channel.id}",
                params: {
                  channel: {
                    name: "A new cat overlord",
                  },
                }
          end

        message = messages[0]
        channel.reload
        expect(message.data[:chat_channel_id]).to eq(channel.id)
        expect(message.data[:name]).to eq(channel.name)
        expect(message.data[:slug]).to eq(channel.slug)
        expect(message.data[:description]).to eq(channel.description)
      end

      it "returns a valid chat channel" do
        put "/chat/api/channels/#{channel.id}", params: { channel: { name: "A new cat is born" } }

        expect(response.parsed_body["channel"]).to match_response_schema("category_chat_channel")
      end

      describe "when updating threading_enabled" do
        it "sets the new value" do
          expect {
            put "/chat/api/channels/#{channel.id}", params: { channel: { threading_enabled: true } }
          }.to change { channel.reload.threading_enabled }.from(false).to(true)

          expect(response.parsed_body["channel"]["threading_enabled"]).to eq(true)
        end
      end

      describe "when updating allow_channel_wide_mentions" do
        it "sets the new value" do
          put "/chat/api/channels/#{channel.id}",
              params: {
                channel: {
                  allow_channel_wide_mentions: false,
                },
              }

          expect(response.parsed_body["channel"]["allow_channel_wide_mentions"]).to eq(false)
        end
      end

      describe "Updating a channel to add users automatically" do
        it "sets the channel to auto-update users automatically" do
          put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: true } }

          expect(response.parsed_body["channel"]["auto_join_users"]).to eq(true)
        end

        it "tells staff members to slow down when toggling auto-update multiple times" do
          RateLimiter.enable

          put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: true } }
          put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: false } }
          put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: true } }

          expect(response.status).to eq(429)
        end

        describe "triggers the auto-join process" do
          fab!(:chatters_group) { Fabricate(:group) }
          fab!(:another_user) { Fabricate(:user, last_seen_at: 15.minute.ago) }

          before do
            Jobs.run_immediately!
            Fabricate(:category_group, category: channel.chatable, group: chatters_group)
            chatters_group.add(another_user)
          end

          it "joins the user when auto_join_users is true" do
            put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: true } }

            created_channel_id = response.parsed_body.dig("channel", "id")
            membership_exists =
              Chat::UserChatChannelMembership.find_by(
                user: another_user,
                chat_channel_id: created_channel_id,
                following: true,
              )

            expect(membership_exists).to be_present
          end

          it "doesn't join the user when auto_join_users is false" do
            put "/chat/api/channels/#{channel.id}", params: { channel: { auto_join_users: false } }

            created_channel_id = response.parsed_body.dig("channel", "id")

            expect(created_channel_id).to be_present

            membership_exists =
              Chat::UserChatChannelMembership.find_by(
                user: another_user,
                chat_channel_id: created_channel_id,
                following: true,
              )

            expect(membership_exists).to be_nil
          end
        end
      end
    end
  end

  def flag_message(message, flagger, flag_type: ReviewableScore.types[:off_topic])
    Chat::ReviewQueue.new.flag_message(message, Guardian.new(flagger), flag_type)[:reviewable]
  end
end
