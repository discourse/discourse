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

    context "when include_messages is true" do
      fab!(:current_user) { Fabricate(:user) }
      fab!(:channel_1) { Fabricate(:category_channel) }
      fab!(:other_user) { Fabricate(:user) }

      describe "target message lookup" do
        let!(:message) { Fabricate(:chat_message, chat_channel: channel_1) }
        let(:chatable) { channel_1.chatable }

        before { sign_in(current_user) }

        context "when the message doesn’t belong to the channel" do
          let!(:message) { Fabricate(:chat_message) }

          it "returns a 404" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }

            expect(response.status).to eq(404)
          end
        end

        context "when the chat channel is for a category" do
          it "ensures the user can access that category" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }
            expect(response.status).to eq(200)
            expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)

            group = Fabricate(:group)
            chatable.update!(read_restricted: true)
            Fabricate(:category_group, group: group, category: chatable)
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }
            expect(response.status).to eq(403)

            GroupUser.create!(user: current_user, group: group)
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }
            expect(response.status).to eq(200)
            expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)
          end
        end

        context "when the chat channel is for a direct message channel" do
          let(:channel_1) { Fabricate(:direct_message_channel) }

          it "ensures the user can access that direct message channel" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }
            expect(response.status).to eq(403)

            Chat::DirectMessageUser.create!(user: current_user, direct_message: chatable)
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  target_message_id: message.id,
                  include_messages: true,
                }
            expect(response.status).to eq(200)
            expect(response.parsed_body["chat_messages"][0]["id"]).to eq(message.id)
          end
        end
      end

      describe "messages pagination and direction" do
        let(:page_size) { 30 }

        message_count = 70
        message_count.times do |n|
          fab!("message_#{n}") do
            Fabricate(
              :chat_message,
              chat_channel: channel_1,
              user: other_user,
              message: "message #{n}",
            )
          end
        end

        before do
          sign_in(current_user)
          Group.refresh_automatic_groups!
        end

        it "errors for user when they are not allowed to chat" do
          SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:staff]
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.status).to eq(403)
        end

        it "errors when page size is over the maximum" do
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: Chat::MessagesQuery::MAX_PAGE_SIZE + 1,
              }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include(
            "Page size must be less than or equal to #{Chat::MessagesQuery::MAX_PAGE_SIZE}",
          )
        end

        it "errors when page size is nil" do
          get "/chat/api/channels/#{channel_1.id}.json", params: { include_messages: true }
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"]).to include("Page size can't be blank")
        end

        it "returns the latest messages in created_at, id order" do
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          messages = response.parsed_body["chat_messages"]
          expect(messages.count).to eq(page_size)
          expect(messages.first["id"]).to eq(message_40.id)
          expect(messages.last["id"]).to eq(message_69.id)
        end

        it "returns `can_flag=true` for public channels" do
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["can_flag"]).to be true
        end

        it "returns `can_flag=true` for DM channels" do
          dm_chat_channel = Fabricate(:direct_message_channel, users: [current_user, other_user])
          get "/chat/api/channels/#{dm_chat_channel.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["can_flag"]).to be true
        end

        it "returns `can_moderate=true` based on whether the user can moderate the chatable" do
          1.upto(4) do |n|
            current_user.update!(trust_level: n)
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  page_size: page_size,
                }
            expect(response.parsed_body["meta"]["can_moderate"]).to be false
          end

          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["can_moderate"]).to be false

          current_user.update!(admin: true)
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["can_moderate"]).to be true
          current_user.update!(admin: false)

          SiteSetting.enable_category_group_moderation = true
          group = Fabricate(:group)
          group.add(current_user)
          channel_1.category.update!(reviewable_by_group: group)
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["can_moderate"]).to be true
        end

        it "serializes `user_flag_status` for user who has a pending flag" do
          chat_message = channel_1.chat_messages.last
          reviewable = flag_message(chat_message, current_user)
          score = reviewable.reviewable_scores.last

          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }

          expect(response.parsed_body["chat_messages"].last["user_flag_status"]).to eq(
            score.status_for_database,
          )
        end

        it "doesn't serialize `reviewable_ids` for non-staff" do
          reviewable = flag_message(channel_1.chat_messages.last, Fabricate(:admin))

          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }

          expect(response.parsed_body["chat_messages"].last["reviewable_id"]).to be_nil
        end

        it "serializes `reviewable_ids` correctly for staff" do
          admin = Fabricate(:admin)
          sign_in(admin)
          reviewable = flag_message(channel_1.chat_messages.last, admin)

          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["chat_messages"].last["reviewable_id"]).to eq(reviewable.id)
        end

        it "correctly marks reactions as 'reacted' for the current_user" do
          heart_emoji = ":heart:"
          smile_emoji = ":smile"
          last_message = channel_1.chat_messages.last
          last_message.reactions.create(user: current_user, emoji: heart_emoji)
          last_message.reactions.create(user: Fabricate(:admin), emoji: smile_emoji)

          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }

          reactions = response.parsed_body["chat_messages"].last["reactions"]
          heart_reaction = reactions.find { |r| r["emoji"] == heart_emoji }
          expect(heart_reaction["reacted"]).to be true
          smile_reaction = reactions.find { |r| r["emoji"] == smile_emoji }
          expect(smile_reaction["reacted"]).to be false
        end

        it "sends the last message bus id for the channel" do
          get "/chat/api/channels/#{channel_1.id}.json",
              params: {
                include_messages: true,
                page_size: page_size,
              }
          expect(response.parsed_body["meta"]["channel_message_bus_last_id"]).not_to eq(nil)
        end

        describe "scrolling to the past" do
          it "returns the correct messages in created_at, id order" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_40.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::PAST,
                }
            messages = response.parsed_body["chat_messages"]
            expect(messages.count).to eq(page_size)
            expect(messages.first["id"]).to eq(message_10.id)
            expect(messages.last["id"]).to eq(message_39.id)
          end

          it "returns 'can_load...' properly when there are more past messages" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_40.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::PAST,
                }
            expect(response.parsed_body["meta"]["can_load_more_past"]).to be true
            expect(response.parsed_body["meta"]["can_load_more_future"]).to be_nil
          end

          it "returns 'can_load...' properly when there are no past messages" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_3.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::PAST,
                }
            expect(response.parsed_body["meta"]["can_load_more_past"]).to be false
            expect(response.parsed_body["meta"]["can_load_more_future"]).to be_nil
          end
        end

        describe "scrolling to the future" do
          it "returns the correct messages in created_at, id order when there are many after" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_10.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::FUTURE,
                }
            messages = response.parsed_body["chat_messages"]
            expect(messages.count).to eq(page_size)
            expect(messages.first["id"]).to eq(message_11.id)
            expect(messages.last["id"]).to eq(message_40.id)
          end

          it "return 'can_load..' properly when there are future messages" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_10.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::FUTURE,
                }
            expect(response.parsed_body["meta"]["can_load_more_past"]).to be_nil
            expect(response.parsed_body["meta"]["can_load_more_future"]).to be true
          end

          it "returns 'can_load..' properly when there are no future messages" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  include_messages: true,
                  target_message_id: message_60.id,
                  page_size: page_size,
                  direction: Chat::MessagesQuery::FUTURE,
                }
            expect(response.parsed_body["meta"]["can_load_more_past"]).to be_nil
            expect(response.parsed_body["meta"]["can_load_more_future"]).to be false
          end
        end

        describe "without direction (latest messages)" do
          it "signals there are no future messages" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  page_size: page_size,
                  include_messages: true,
                }

            expect(response.parsed_body["meta"]["can_load_more_future"]).to eq(false)
          end

          it "signals there are more messages in the past" do
            get "/chat/api/channels/#{channel_1.id}.json",
                params: {
                  page_size: page_size,
                  include_messages: true,
                }

            expect(response.parsed_body["meta"]["can_load_more_past"]).to eq(true)
          end

          it "signals there are no more messages" do
            new_channel = Fabricate(:category_channel)
            Fabricate(
              :chat_message,
              chat_channel: new_channel,
              user: other_user,
              message: "message",
            )
            chat_messages_qty = 1

            get "/chat/api/channels/#{new_channel.id}.json",
                params: {
                  page_size: chat_messages_qty + 1,
                  include_messages: true,
                }

            expect(response.parsed_body["meta"]["can_load_more_past"]).to eq(false)
          end
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
        before { SiteSetting.enable_experimental_chat_threaded_discussions = true }

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
