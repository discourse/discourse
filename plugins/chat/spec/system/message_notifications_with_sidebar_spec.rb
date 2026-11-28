# frozen_string_literal: true

RSpec.describe "Message notifications - with sidebar" do
  fab!(:current_user, :user)

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
  end

  let(:sidebar) { PageObjects::Pages::ChatSidebar.new }
  let(:header) { PageObjects::Components::Chat::Header.new }

  def create_message(text: nil, channel: nil, thread: nil, creator:)
    result =
      Chat::CreateMessage.call(
        guardian: creator.guardian,
        params: {
          chat_channel_id: (channel || thread.channel).id,
          thread_id: thread&.id,
          message: text || fake_chat_message,
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
              visit("/")
              create_message(channel: channel_1, creator: user_1)

              expect(header).to have_open_chat_button
              expect(sidebar).to have_no_channel(channel_1)
              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
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

            it "doesn’t show indicator in header" do
              visit("/")
              create_message(channel: channel_1, creator: user_1)

              expect(page).to have_css(".do-not-disturb-background")
              expect(header).to have_open_chat_button
              expect(sidebar).to have_unread_channel(channel_1)
              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
            end
          end

          context "when channel is muted" do
            before { channel_1.membership_for(current_user).update!(muted: true) }

            context "when a message is created" do
              it "doesn't show anything" do
                visit("/")
                create_message(channel: channel_1, creator: user_1)

                expect(header).to have_open_chat_button
                expect(sidebar).to have_channel(channel_1)
                expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
                expect(sidebar).to have_no_unread_channel(channel_1)
              end
            end
          end

          context "when user chat_header_indicator_preference is set to 'never'" do
            before do
              current_user.user_option.update!(
                chat_header_indicator_preference:
                  UserOption.chat_header_indicator_preferences[:never],
              )
            end

            context "when a message is created" do
              it "doesn't show any indicator on chat-header-icon" do
                visit("/")
                create_message(channel: channel_1, creator: user_1)

                expect(header).to have_open_chat_button
                expect(sidebar).to have_unread_channel(channel_1)

                expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
              end
            end
          end

          context "when user chat_header_indicator_preference is set to 'dm_and_mentions'" do
            before do
              current_user.user_option.update!(
                chat_header_indicator_preference:
                  UserOption.chat_header_indicator_preferences[:dm_and_mentions],
              )
            end

            context "when a message is created" do
              it "doesn't show any indicator on chat-header-icon" do
                visit("/")
                create_message(channel: channel_1, creator: user_1)

                expect(header).to have_open_chat_button
                expect(sidebar).to have_unread_channel(channel_1)

                expect(page).to have_no_css(
                  ".chat-header-icon .chat-channel-unread-indicator.-urgent",
                )
              end
            end

            context "when a message with a mention is created" do
              it "does show an indicator on chat-header-icon" do
                Jobs.run_immediately!
                visit("/")
                create_message(
                  text: "hey what's going on @#{current_user.username}?",
                  channel: channel_1,
                  creator: user_1,
                )

                expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator.-urgent")
              end
            end
          end

          context "when a message is created" do
            it "correctly renders notifications" do
              visit("/")
              create_message(channel: channel_1, creator: user_1)

              expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "")
              expect(page).to have_css(".sidebar-row.channel-#{channel_1.id} .unread")
            end
          end

          context "when a message with mentions is created" do
            it "correctly renders notifications" do
              Jobs.run_immediately!
              visit("/")
              create_message(
                channel: channel_1,
                creator: user_1,
                text: "hello @#{current_user.username} what's up?",
              )

              expect(page).to have_css(
                ".chat-header-icon .chat-channel-unread-indicator.-urgent",
                text: "1",
              )
              expect(page).to have_css(".sidebar-row.channel-#{channel_1.id} .icon.urgent")
            end
          end
        end
      end

      context "when a new direct message channel is created" do
        fab!(:other_user, :user)
        let!(:chat_sidebar) { PageObjects::Components::Chat::Sidebar.new }

        it "shows the channel in the sidebar without reload" do
          visit("/")

          expect(chat_sidebar).to have_start_new_dm

          result =
            Chat::CreateDirectMessageChannel.call(
              guardian: other_user.guardian,
              params: {
                target_usernames: [current_user.username],
              },
            )
          service_failed!(result) if result.failure?

          dm_channel = result.channel

          create_message(channel: dm_channel, creator: other_user)

          expect(chat_sidebar).to have_direct_message_channel(dm_channel, mention: true)
          expect(chat_sidebar).to have_no_start_new_dm
        end
      end

      context "with dm channel" do
        fab!(:current_user, :admin)
        fab!(:user_1, :user)
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        context "when chat_header_indicator_preference is 'only_mentions'" do
          before do
            current_user.user_option.update!(
              chat_header_indicator_preference:
                UserOption.chat_header_indicator_preferences[:only_mentions],
            )
          end

          it "doesn't show indicator on chat-header-icon for messages" do
            visit("/")
            create_message(channel: dm_channel_1, creator: user_1)
            expect(header).to have_open_chat_button
            expect(page).to have_css(".sidebar-row.channel-#{dm_channel_1.id} .urgent")
            expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator.-urgent")
          end

          it "does show an indicator on chat-header-icon for mentions" do
            Jobs.run_immediately!
            visit("/")
            create_message(
              text: "hey what's up @#{current_user.username}?",
              channel: dm_channel_1,
              creator: user_1,
            )

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator.-urgent")
          end
        end

        context "when a message is created" do
          it "correctly renders notifications" do
            visit("/")
            create_message(channel: dm_channel_1, creator: user_1)

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "1")
            expect(page).to have_css(".sidebar-row.channel-#{dm_channel_1.id} .icon.urgent")

            create_message(channel: dm_channel_1, creator: user_1)

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "2")
          end

          context "with a second DM channel" do
            fab!(:user_2, :user)
            fab!(:dm_channel_2) do
              Fabricate(:direct_message_channel, users: [current_user, user_2])
            end

            it "reorders channels" do
              visit("/chat")

              expect(page).to have_css(
                "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(1) .channel-#{dm_channel_1.id}",
              )
              expect(page).to have_css(
                "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(2) .channel-#{dm_channel_2.id}",
              )

              create_message(channel: dm_channel_2, creator: user_2)

              expect(page).to have_css(
                "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(1) .channel-#{dm_channel_2.id}",
              )
              expect(page).to have_css(
                "#sidebar-section-content-chat-dms .sidebar-section-link-wrapper:nth-child(2) .channel-#{dm_channel_1.id}",
              )
            end
          end
        end
      end

      context "with threads" do
        fab!(:other_user, :user)

        context "with public channels" do
          fab!(:channel) { Fabricate(:category_channel, threading_enabled: true) }
          fab!(:thread) do
            Fabricate(:chat_thread, channel: channel, original_message_user: current_user)
          end
          fab!(:reply) do
            Fabricate(:chat_message, chat_channel: channel, thread: thread, user: other_user)
          end

          before do
            channel.add(other_user)
            channel.update!(last_message_id: thread.original_message_id, messages_count: 1)
            channel.add(current_user).mark_read!(thread.original_message_id)
            thread.update_last_message_id!
            thread.set_replies_count_cache(1, update_db: true)
            thread.add(other_user).mark_read!(reply.id)
            thread.membership_for(current_user).mark_read!(reply.id)

            visit("/")
          end

          it "shows the unread badge in chat header" do
            expect(header).to have_open_chat_button
            expect(sidebar).to have_channel(channel)
            expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")

            create_message(thread: thread, creator: other_user, text: "this is a test")

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator")
          end
        end

        context "with direct message channels" do
          fab!(:dm_channel) do
            Fabricate(
              :direct_message_channel,
              users: [current_user, other_user],
              threading_enabled: true,
            )
          end
          fab!(:thread) do
            Fabricate(:chat_thread, channel: dm_channel, original_message_user: current_user)
          end
          fab!(:reply) do
            Fabricate(:chat_message, chat_channel: dm_channel, thread: thread, user: other_user)
          end

          before do
            dm_channel.update!(last_message_id: thread.original_message_id, messages_count: 1)
            dm_channel.membership_for(current_user).mark_read!(thread.original_message_id)
            thread.update_last_message_id!
            thread.set_replies_count_cache(1, update_db: true)
            thread.add(other_user).mark_read!(reply.id)
            thread.membership_for(current_user).mark_read!(reply.id)

            visit("/")
          end

          it "shows the unread indicator in the sidebar for tracked threads" do
            expect(sidebar).to have_channel(dm_channel)
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .unread")

            create_message(channel: dm_channel, thread: thread, creator: other_user)

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .unread")
          end

          it "shows the urgent indicator in the sidebar for tracked threads" do
            expect(sidebar).to have_channel(dm_channel)
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .urgent")

            thread.membership_for(current_user).update!(notification_level: :watching)

            create_message(channel: dm_channel, thread: thread, creator: other_user)

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .urgent")
          end

          it "shows the urgent indicator in the chat sidebar for mentions" do
            expect(sidebar).to have_channel(dm_channel)
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .urgent")

            create_message(
              channel: dm_channel,
              thread: thread,
              creator: other_user,
              text: "hey @#{current_user.username}",
            )

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .urgent")
          end
        end

        context "with direct message replies (threading disabled)" do
          fab!(:dm_channel) do
            Fabricate(:direct_message_channel, users: [current_user, other_user])
          end

          fab!(:first_message) do
            Fabricate(:chat_message, chat_channel: dm_channel, user: other_user)
          end

          it "shows the urgent indicator when someone replies to a message" do
            dm_channel.update!(last_message: first_message, messages_count: 1)
            dm_channel.membership_for(other_user).mark_read!(first_message.id)
            dm_channel.membership_for(current_user).mark_read!(first_message.id)

            visit("/")
            expect(sidebar).to have_channel(dm_channel)
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .urgent")

            Chat::CreateMessage.call(
              guardian: other_user.guardian,
              params: {
                chat_channel_id: dm_channel.id,
                message: "This is a reply",
                in_reply_to_id: first_message.id,
              },
            )

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .urgent")
          end
        end

        context "with category channel replies (threading disabled)" do
          fab!(:channel) { Fabricate(:category_channel, threading_enabled: false) }
          fab!(:first_message) do
            Fabricate(:chat_message, chat_channel: channel, user: current_user)
          end

          before do
            channel.update!(last_message: first_message, messages_count: 1)
            channel.add(current_user).mark_read!(first_message.id)
            channel.add(other_user)
          end

          def reply_to_first_message
            Chat::CreateMessage.call(
              guardian: other_user.guardian,
              params: {
                chat_channel_id: channel.id,
                message: "This is a reply",
                in_reply_to_id: first_message.id,
              },
            )
          end

          it "shows the unread indicator when someone replies to the user's message" do
            visit("/")
            expect(sidebar).to have_channel(channel)
            expect(sidebar).to have_no_unread_channel(channel)

            reply_to_first_message

            expect(page).to have_css(".sidebar-row.channel-#{channel.id} .unread")
          end

          it "shows the unread indicator on a fresh page load after the reply" do
            reply_to_first_message

            visit("/")

            expect(page).to have_css(".sidebar-row.channel-#{channel.id} .unread")
          end
        end
      end
    end
  end
end
