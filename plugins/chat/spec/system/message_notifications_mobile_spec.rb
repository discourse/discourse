# frozen_string_literal: true

RSpec.describe "Message notifications - mobile", mobile: true do
  fab!(:current_user, :user)

  let!(:chat_page) { PageObjects::Pages::Chat.new }
  let!(:channels_index_page) { PageObjects::Components::Chat::ChannelsIndex.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
  end

  let(:header) { PageObjects::Components::Chat::Header.new }

  def create_message(chat_channel, message: nil, user:, thread: nil)
    result =
      Chat::CreateMessage.call(
        guardian: user.guardian,
        params: {
          chat_channel_id: chat_channel.id,
          thread_id: thread&.id,
          message: message || fake_chat_message,
        },
        options: {
          process_inline: true,
        },
      )
    service_failed!(result) if result.failure?
    result.message_instance
  end

  context "as a user" do
    before { sign_in(current_user) }

    context "when on homepage" do
      context "with public channel" do
        fab!(:channel_1, :category_channel)
        fab!(:user_1, :user)

        before { channel_1.add(user_1) }

        context "when not member of the channel" do
          context "when a message is created" do
            it "doesn't show anything" do
              visit("/chat")

              create_message(channel_1, user: user_1)

              expect(page).to have_css("#public-channels .empty-state")
              expect(channels_index_page).to have_no_channel(channel_1)
              expect(find("#c-footer-channels")).to have_no_css(".c-unread-indicator")
            end
          end
        end

        context "when member of the channel" do
          before { channel_1.add(current_user) }

          context "when user is in DnD" do
            fab!(:dnd) do
              Fabricate(
                :do_not_disturb_timing,
                user: current_user,
                starts_at: 1.week.ago,
                ends_at: 1.week.from_now,
              )
            end

            it "doesn't show an unread badge on the forum header's chat icon" do
              visit("/")

              create_message(channel_1, user: user_1)

              expect(page).to have_css(".do-not-disturb-background")
              expect(header).to have_open_chat_button
              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
            end

            it "shows Do Not Disturb when the user opens chat directly" do
              visit("/chat")

              expect(channels_index_page).to have_channel(channel_1)
              expect(page).to have_css(".has-full-page-chat .do-not-disturb-background")
            end
          end

          context "when channel is muted" do
            before { channel_1.membership_for(current_user).update!(muted: true) }

            context "when a message is created" do
              it "doesn't show anything" do
                visit("/chat")

                create_message(channel_1, user: user_1)

                expect(channels_index_page).to have_channel(channel_1)
                expect(channels_index_page).to have_no_unread_channel(channel_1)
                expect(find("#c-footer-channels")).to have_no_css(".c-unread-indicator")
              end
            end
          end

          context "when a message is created" do
            it "correctly renders notifications" do
              visit("/chat/channels")

              create_message(channel_1, user: user_1)

              expect(channels_index_page).to have_unread_channel(channel_1)
              expect(chat_page.footer).to have_unread_channels
            end
          end

          context "when a message with mentions is created" do
            it "correctly renders notifications" do
              Jobs.run_immediately!

              visit("/chat/channels")

              create_message(
                channel_1,
                user: user_1,
                message: "hello @#{current_user.username} what's up?",
              )

              expect(channels_index_page).to have_unread_channel(channel_1, count: 1)
              expect(chat_page.footer).to have_unread_channels
            end

            it "shows correct count when there are multiple messages but only 1 is urgent" do
              Jobs.run_immediately!

              visit("/chat/channels")

              create_message(
                channel_1,
                user: user_1,
                message: "Are you busy @#{current_user.username}?",
              )

              3.times { create_message(channel_1, user: user_1) }

              expect(channels_index_page).to have_unread_channel(channel_1, count: 1)
              expect(chat_page.footer).to have_unread_channels
            end
          end
        end
      end

      context "with dm channel" do
        fab!(:current_user, :admin)
        fab!(:user_1, :user)
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        context "when a message is created" do
          it "correctly renders notifications" do
            visit("/chat/direct-messages")

            create_message(dm_channel_1, user: user_1)
            expect(channels_index_page).to have_unread_channel(dm_channel_1, count: 1, wait: 25)
            expect(chat_page.footer).to have_unread_dms("1")

            create_message(dm_channel_1, user: user_1)
            expect(channels_index_page).to have_unread_channel(dm_channel_1, count: 2, wait: 25)
            expect(chat_page.footer).to have_unread_dms("2")
          end

          context "with a second DM channel" do
            fab!(:user_2, :user)
            fab!(:dm_channel_2) do
              Fabricate(:direct_message_channel, users: [current_user, user_2])
            end

            it "reorders channels" do
              visit("/chat/direct-messages")

              expect(page).to have_css(
                ".chat-channel-row:nth-child(1)[data-chat-channel-id=\"#{dm_channel_1.id}\"]",
              )
              expect(page).to have_css(
                ".chat-channel-row:nth-child(2)[data-chat-channel-id=\"#{dm_channel_2.id}\"]",
              )

              create_message(dm_channel_2, user: user_2)

              expect(page).to have_css(
                ".chat-channel-row:nth-child(1)[data-chat-channel-id=\"#{dm_channel_2.id}\"]",
              )
              expect(page).to have_css(
                ".chat-channel-row:nth-child(2)[data-chat-channel-id=\"#{dm_channel_1.id}\"]",
              )
            end
          end

          context "with threads" do
            fab!(:message) do
              Fabricate(:chat_message, chat_channel: dm_channel_1, user: current_user)
            end
            fab!(:thread) do
              Fabricate(:chat_thread, channel: dm_channel_1, original_message: message)
            end

            before do
              dm_channel_1.update!(last_message: message, messages_count: 1)
              dm_channel_1.membership_for(current_user).mark_read!(message.id)
              thread.membership_for(current_user).mark_read!(message.id)
            end

            it "shows urgent badge for mentions" do
              Jobs.run_immediately!

              visit("/chat/direct-messages")

              expect(channels_index_page).to have_channel(dm_channel_1)
              expect(channels_index_page).to have_no_unread_channel(dm_channel_1)

              create_message(
                dm_channel_1,
                thread: thread,
                message: "hello @#{current_user.username}",
                user: user_1,
              )

              expect(channels_index_page).to have_unread_channel(dm_channel_1, urgent: true)
            end
          end
        end
      end

      context "with dm and public channel" do
        fab!(:current_user, :admin)
        fab!(:user_1, :user)
        fab!(:channel_1, :category_channel)
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        before do
          channel_1.add(user_1)
          channel_1.add(current_user)
        end

        context "when messages are created" do
          it "correctly renders notifications" do
            visit("/chat/channels")
            create_message(channel_1, user: user_1)
            expect(channels_index_page).to have_unread_channel(channel_1)

            find("#c-footer-direct-messages").click
            expect(channels_index_page).to have_channel(dm_channel_1)

            create_message(dm_channel_1, user: user_1)
            expect(channels_index_page).to have_unread_channel(dm_channel_1)
          end
        end
      end
    end

    context "when viewing a channel" do
      fab!(:channel_1, :category_channel)
      fab!(:channel_2, :category_channel)
      fab!(:user_1, :user)

      before do
        channel_1.add(current_user)
        channel_1.add(user_1)
        channel_2.add(current_user)
        channel_2.add(user_1)

        Jobs.run_immediately!
      end

      it "shows back button urgent indicator for mentions in other channels" do
        chat_page.visit_channel(channel_1)

        create_message(channel_2, user: user_1, message: "hey @#{current_user.username}")

        expect(page).to have_css(".c-navbar__back-button .chat-channel-unread-indicator.-urgent")
      end

      it "shows back button unread indicator for messages in other channels" do
        chat_page.visit_channel(channel_1)

        create_message(channel_2, user: user_1)

        expect(page).to have_css(
          ".c-navbar__back-button .chat-channel-unread-indicator:not(.-urgent)",
        )
      end

      it "does not show back button indicator for current channel unreads" do
        message = create_message(channel_1, user: user_1, message: "hey @#{current_user.username}")

        chat_page.visit_channel(channel_1)

        expect(PageObjects::Pages::ChatChannel.new.messages).to have_message(id: message.id)
        expect(find(".c-navbar__back-button")).to have_no_css(".chat-channel-unread-indicator")
      end
    end
  end
end
