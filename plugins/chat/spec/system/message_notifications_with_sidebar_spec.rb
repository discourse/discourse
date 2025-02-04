# frozen_string_literal: true

RSpec.describe "Message notifications - with sidebar", type: :system do
  fab!(:current_user) { Fabricate(:user) }

  let!(:chat_page) { PageObjects::Pages::Chat.new }
  let!(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let!(:thread_page) { PageObjects::Pages::ChatThread.new }
  let!(:sidebar) { PageObjects::Pages::Sidebar.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
  end

  def create_message(text: nil, channel: nil, thread: nil, creator: Fabricate(:user))
    Fabricate(
      :chat_message_with_service,
      chat_channel: channel,
      thread: thread,
      message: text,
      user: creator,
    )
  end

  context "as a user" do
    before { sign_in(current_user) }

    context "when on homepage" do
      context "with public channel" do
        fab!(:channel_1) { Fabricate(:category_channel) }
        fab!(:channel_2) { Fabricate(:category_channel) }
        fab!(:user_1) { Fabricate(:user) }

        before { channel_1.add(user_1) }

        context "when not member of the channel" do
          context "when a message is created" do
            it "doesn't show anything" do
              visit("/")
              create_message(channel: channel_1, creator: user_1)

              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
              expect(page).to have_no_css(".sidebar-row.channel-#{channel_1.id}")
            end
          end
        end

        context "when member of the channel" do
          before { channel_1.add(current_user) }

          context "when user is in DnD" do
            before do
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
              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
            end
          end

          context "when channel is muted" do
            before { channel_1.membership_for(current_user).update!(muted: true) }

            context "when a message is created" do
              it "doesn't show anything" do
                visit("/")
                create_message(channel: channel_1, creator: user_1)

                expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
                expect(page).to have_no_css(".sidebar-row.channel-#{channel_1.id} .unread")
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

      context "with dm channel" do
        fab!(:current_user) { Fabricate(:admin) }
        fab!(:user_1) { Fabricate(:user) }
        fab!(:user_2) { Fabricate(:user) }

        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }
        fab!(:dm_channel_2) { Fabricate(:direct_message_channel, users: [current_user, user_2]) }

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

      context "with threads" do
        fab!(:other_user) { Fabricate(:user) }

        context "with public channels" do
          fab!(:channel) { Fabricate(:category_channel, threading_enabled: true) }
          fab!(:thread) do
            chat_thread_chain_bootstrap(channel: channel, users: [current_user, other_user])
          end

          before do
            channel.membership_for(current_user).mark_read!
            thread.membership_for(current_user).mark_read!

            visit("/")
          end

          it "shows the unread badge in chat header" do
            expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")

            create_message(thread: thread, creator: other_user, text: "this is a test")

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator")
          end
        end

        context "with direct message channels" do
          fab!(:dm_channel) do
            Fabricate(:direct_message_channel, users: [current_user, other_user])
          end
          fab!(:thread) do
            chat_thread_chain_bootstrap(channel: dm_channel, users: [current_user, other_user])
          end

          before do
            dm_channel.membership_for(current_user).mark_read!
            thread.membership_for(current_user).mark_read!

            visit("/")
          end

          it "shows the unread indicator in the sidebar for tracked threads" do
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .unread")

            create_message(channel: dm_channel, thread: thread, creator: other_user)

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .unread")
          end

          it "shows the urgent indicator in the sidebar for tracked threads" do
            expect(page).to have_no_css(".sidebar-row.channel-#{dm_channel.id} .urgent")

            thread.membership_for(current_user).update!(notification_level: :watching)

            create_message(channel: dm_channel, thread: thread, creator: other_user)

            expect(page).to have_css(".sidebar-row.channel-#{dm_channel.id} .urgent")
          end

          it "shows the urgent indicator in the chat sidebar for mentions" do
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
      end
    end
  end
end
