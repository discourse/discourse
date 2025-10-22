# frozen_string_literal: true

RSpec.describe "Archive channel", type: :system do
  fab!(:channel_1, :chat_channel)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when archiving is disabled" do
    context "when admin user" do
      fab!(:current_user, :admin)

      before { sign_in(current_user) }

      it "doesn’t allow to archive a channel" do
        chat.visit_channel_settings(channel_1)

        expect(page).to have_no_content(I18n.t("js.chat.channel_settings.archive_channel"))
      end
    end
  end

  context "when archiving is enabled" do
    before { SiteSetting.chat_allow_archiving_channels = true }

    context "when regular user" do
      fab!(:current_user, :user)

      before { sign_in(current_user) }

      it "doesn’t allow to archive a channel" do
        chat.visit_channel_settings(channel_1)

        expect(page).to have_no_content(I18n.t("js.chat.channel_settings.archive_channel"))
      end
    end

    context "when admin user" do
      fab!(:current_user, :admin)

      before { sign_in(current_user) }

      it "allows to archive a channel" do
        chat.visit_channel_settings(channel_1)

        expect(page).to have_content(I18n.t("js.chat.channel_settings.archive_channel"))
      end

      context "when archiving" do
        it "works" do
          Jobs.run_immediately!

          chat.visit_channel_settings(channel_1)
          click_button(I18n.t("js.chat.channel_settings.archive_channel"))
          find("#split-topic-name").fill_in(with: "An interesting topic for cats")
          click_button(I18n.t("js.chat.channel_archive.title"))

          expect(page).to have_css(".chat-channel-archive-status", wait: 15)
        end

        context "when archived channels had unreads" do
          let(:other_user) { Fabricate(:user) }

          before do
            channel_1.add(current_user)
            channel_1.add(other_user)
          end

          it "clears unread indicators" do
            Jobs.run_immediately!

            Fabricate(
              :chat_message,
              chat_channel: channel_1,
              user: other_user,
              message: "this is fine @#{current_user.username}",
              use_service: true,
            )

            visit("/")
            expect(page.find(".chat-channel-unread-indicator")).to have_content(1)

            chat.visit_channel_settings(channel_1)
            click_button(I18n.t("js.chat.channel_settings.archive_channel"))
            find("#split-topic-name").fill_in(with: "An interesting topic for cats")
            click_button(I18n.t("js.chat.channel_archive.title"))

            expect(page).to have_no_css(".chat-channel-unread-indicator")
          end
        end
      end

      context "when archiving failed" do
        before { channel_1.update!(status: :read_only) }

        fab!(:archive) do
          Chat::ChannelArchive.create!(
            chat_channel: channel_1,
            archived_by: current_user,
            destination_topic_title: "This will be the archive topic",
            total_messages: 2,
            archived_messages: 1,
            archive_error: "Something went wrong",
          )
        end

        xit "can be retried" do
          Jobs.run_immediately!

          chat.visit_channel(channel_1)
          click_button(I18n.t("js.chat.channel_archive.retry"))
          expect(page).to have_css(".chat-channel-archive-status a")

          new_window = window_opened_by { find(".chat-channel-archive-status a").click }
          within_window(new_window) do
            expect(page).to have_content(archive.destination_topic_title)
          end
        end
      end
    end
  end
end
