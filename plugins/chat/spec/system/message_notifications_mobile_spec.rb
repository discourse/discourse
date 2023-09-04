# frozen_string_literal: true

RSpec.describe "Message notifications - mobile", type: :system, mobile: true do
  fab!(:current_user) { Fabricate(:user) }

  let!(:chat_page) { PageObjects::Pages::Chat.new }
  let!(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }
  let!(:channel_index_page) { PageObjects::Components::Chat::ChannelIndex.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
  end

  def create_message(text: "this is fine", channel:, creator: Fabricate(:user))
    sign_in(creator)
    chat_page.visit_channel(channel)
    chat_channel_page.send_message(text)
    expect(chat_channel_page.messages).to have_message(text: text)
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
              Jobs.run_immediately!

              visit("/chat")
              using_session(:user_1) do |session|
                create_message(channel: channel_1, creator: user_1)
                session.quit
              end

              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
              expect(page).to have_no_css(channel_index_page.channel_row_selector(channel_1))
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
              Jobs.run_immediately!

              visit("/chat")
              using_session(:user_1) do |session|
                create_message(channel: channel_1, creator: user_1)
                session.quit
              end

              expect(page).to have_css(".do-not-disturb-background")
              expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
            end
          end

          context "when channel is muted" do
            before { channel_1.membership_for(current_user).update!(muted: true) }

            context "when a message is created" do
              it "doesn't show anything" do
                Jobs.run_immediately!

                visit("/chat")
                using_session(:user_1) do |session|
                  create_message(channel: channel_1, creator: user_1)
                  session.quit
                end

                expect(page).to have_no_css(".chat-header-icon .chat-channel-unread-indicator")
                expect(channel_index_page).to have_no_unread_channel(channel_1)
              end
            end
          end

          context "when a message is created" do
            it "correctly renders notifications" do
              Jobs.run_immediately!

              visit("/chat")
              using_session(:user_1) do |session|
                create_message(channel: channel_1, creator: user_1)
                session.quit
              end

              expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "")
              expect(channel_index_page).to have_unread_channel(channel_1)
            end
          end

          context "when a message with mentions is created" do
            it "correctly renders notifications" do
              Jobs.run_immediately!

              visit("/chat")
              using_session(:user_1) do
                create_message(
                  channel: channel_1,
                  creator: user_1,
                  text: "hello @#{current_user.username} what's up?",
                )
              end

              expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator")
              expect(channel_index_page).to have_unread_channel(channel_1, count: 1)
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

        context "when a message is created" do
          it "correctly renders notifications" do
            Jobs.run_immediately!

            visit("/chat")
            using_session(:user_1) do |session|
              create_message(channel: dm_channel_1, creator: user_1)
              session.quit
            end

            expect(page).to have_css(
              ".chat-header-icon .chat-channel-unread-indicator",
              text: "1",
              wait: 25,
            )
            expect(channel_index_page).to have_unread_channel(dm_channel_1, wait: 25)

            using_session(:user_1) do |session|
              create_message(channel: dm_channel_1, creator: user_1)
              session.quit
            end

            expect(page).to have_css(
              ".chat-header-icon .chat-channel-unread-indicator",
              text: "2",
              wait: 25,
            )
          end

          it "reorders channels" do
            Jobs.run_immediately!

            visit("/chat")

            expect(page).to have_css(
              ".chat-channel-row:nth-child(1)[data-chat-channel-id=\"#{dm_channel_1.id}\"]",
            )
            expect(page).to have_css(
              ".chat-channel-row:nth-child(2)[data-chat-channel-id=\"#{dm_channel_2.id}\"]",
            )

            using_session(:user_1) do |session|
              create_message(channel: dm_channel_2, creator: user_2)
              session.quit
            end

            expect(page).to have_css(
              ".chat-channel-row:nth-child(1)[data-chat-channel-id=\"#{dm_channel_2.id}\"]",
            )
            expect(page).to have_css(
              ".chat-channel-row:nth-child(2)[data-chat-channel-id=\"#{dm_channel_1.id}\"]",
            )
          end
        end
      end

      context "with dm and public channel" do
        fab!(:current_user) { Fabricate(:admin) }
        fab!(:user_1) { Fabricate(:user) }
        fab!(:channel_1) { Fabricate(:category_channel) }
        fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user, user_1]) }

        before do
          channel_1.add(user_1)
          channel_1.add(current_user)
        end

        context "when messages are created" do
          it "correctly renders notifications" do
            Jobs.run_immediately!

            visit("/chat")
            using_session(:user_1) do |session|
              create_message(channel: channel_1, creator: user_1)
              session.quit
            end

            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "")
            expect(channel_index_page).to have_unread_channel(channel_1)

            using_session(:user_1) do |session|
              create_message(channel: dm_channel_1, creator: user_1)
              session.quit
            end

            expect(channel_index_page).to have_unread_channel(dm_channel_1)
            expect(page).to have_css(".chat-header-icon .chat-channel-unread-indicator", text: "1")
          end
        end
      end
    end
  end
end
