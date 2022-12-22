# frozen_string_literal: true

RSpec.describe "Archive channel", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when archiving is disabled" do
    context "when admin user" do
      fab!(:current_user) { Fabricate(:admin) }

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
      fab!(:current_user) { Fabricate(:user) }

      before { sign_in(current_user) }

      it "doesn’t allow to archive a channel" do
        chat.visit_channel_settings(channel_1)

        expect(page).to have_no_content(I18n.t("js.chat.channel_settings.archive_channel"))
      end
    end

    context "when admin user" do
      fab!(:current_user) { Fabricate(:admin) }

      before { sign_in(current_user) }

      it "allows to archive a channel" do
        chat.visit_channel_settings(channel_1)

        expect(page).to have_content(I18n.t("js.chat.channel_settings.archive_channel"))
      end

      context "when archiving" do
        before { Jobs.run_immediately! }

        it "works" do
          chat.visit_channel_settings(channel_1)
          click_button(I18n.t("js.chat.channel_settings.archive_channel"))
          find("#split-topic-name").fill_in(with: "An interesting topic for cats")
          click_button(I18n.t("js.chat.channel_archive.title"))

          expect(page).to have_content(I18n.t("js.chat.channel_archive.process_started"))

          chat.visit_channel(channel_1)

          expect(page).to have_content(I18n.t("js.chat.channel_status.archived_header"))
        end

        context "when archived channels had unreads" do
          before do
            other_user = Fabricate(:user)
            channel_1.add(other_user)
            channel_1.add(current_user)
            Chat::ChatMessageCreator.create(
              chat_channel: channel_1,
              user: other_user,
              content: "this is fine @#{current_user.username}",
            )
          end

          it "clears unread indicators" do
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
        before do
          Jobs.run_immediately!
          channel_1.update!(status: :read_only)
        end

        fab!(:archive) do
          ChatChannelArchive.create!(
            chat_channel: channel_1,
            archived_by: current_user,
            destination_topic_title: "This will be the archive topic",
            total_messages: 2,
            archived_messages: 1,
            archive_error: "Something went wrong",
          )
        end

        it "can be retried" do
          chat.visit_channel(channel_1)
          click_button(I18n.t("js.chat.channel_archive.retry"))
          visit(find(".chat-channel-archive-status a")["href"])

          expect(page).to have_content(archive.destination_topic_title)
        end
      end
    end
  end
end
