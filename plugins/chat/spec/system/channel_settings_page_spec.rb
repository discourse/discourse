# frozen_string_literal: true

RSpec.describe "Channel - Info - Settings page", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "as unauthorized user" do
    before { SiteSetting.chat_allowed_groups = Fabricate(:group).id }

    it "redirects to home page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/latest")
    end
  end

  context "as authorized user" do
    context "as not member" do
      it "redirects to about tab" do
        chat_page.visit_channel_settings(channel_1)

        expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/about")
      end

      it "doesn’t have settings tab" do
        chat_page.visit_channel_settings(channel_1)

        expect(page).to have_no_selector(".chat-tabs-list__item[aria-controls='settings-tab']")
      end

      context "as an admin" do
        before { sign_in(Fabricate(:admin)) }

        it "shows settings tab" do
          chat_page.visit_channel_settings(channel_1)

          expect(page).to have_selector(".chat-tabs-list__item[aria-controls='settings-tab']")
        end

        it "can navigate to settings tab" do
          chat_page.visit_channel_settings(channel_1)

          expect(page).to have_current_path(
            "/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings",
          )
        end
      end
    end

    context "as a member" do
      before { channel_1.add(current_user) }

      context "when visitng the settings of a recently joined channel" do
        fab!(:channel_2) { Fabricate(:category_channel) }

        it "is correctly populated" do
          chat_page.visit_browse
          find(
            ".chat-channel-card[data-channel-id='#{channel_2.id}'] .toggle-channel-membership-button",
          ).click

          expect(
            page.find(".chat-channel-card[data-channel-id='#{channel_2.id}']"),
          ).to have_content(I18n.t("js.chat.joined").upcase)

          find(
            ".chat-channel-card[data-channel-id='#{channel_2.id}'] .chat-channel-card__setting",
          ).click

          expect(page).to have_content(I18n.t("js.chat.notification_levels.mention"))
        end
      end

      it "can mute channel" do
        chat_page.visit_channel_settings(channel_1)
        membership = channel_1.membership_for(current_user)

        expect {
          find(".channel-settings-view__muted-selector").click
          find(".channel-settings-view__muted-selector [data-name='On']").click
          expect(page).to have_content(I18n.t("js.chat.settings.saved"))
        }.to change { membership.reload.muted }.from(false).to(true)
      end

      it "can change desktop notification level" do
        chat_page.visit_channel_settings(channel_1)
        membership = channel_1.membership_for(current_user)

        expect {
          find(".channel-settings-view__desktop-notification-level-selector").click
          find(
            ".channel-settings-view__desktop-notification-level-selector [data-name='Never']",
          ).click
          expect(page).to have_content(I18n.t("js.chat.settings.saved"))
        }.to change { membership.reload.desktop_notification_level }.from("mention").to("never")
      end

      it "can change mobile notification level" do
        chat_page.visit_channel_settings(channel_1)
        membership = channel_1.membership_for(current_user)

        expect {
          find(".channel-settings-view__mobile-notification-level-selector").click
          find(
            ".channel-settings-view__mobile-notification-level-selector [data-name='Never']",
          ).click
          expect(page).to have_content(I18n.t("js.chat.settings.saved"))
        }.to change { membership.reload.mobile_notification_level }.from("mention").to("never")
      end

      it "doesn’t show admin section" do
        chat_page.visit_channel_settings(channel_1)

        expect(page).to have_no_content(I18n.t("js.chat.settings.admin_title"))
      end

      context "as an admin" do
        before { sign_in(Fabricate(:admin)) }

        it "shows admin section" do
          chat_page.visit_channel_settings(channel_1)

          expect(page).to have_content(I18n.t("js.chat.settings.admin_title"))
        end

        it "can change auto join setting" do
          chat_page.visit_channel_settings(channel_1)

          expect {
            find(".channel-settings-view__auto-join-selector").click
            find(".channel-settings-view__auto-join-selector [data-name='Yes']").click
            find("#dialog-holder .btn-primary").click
            expect(page).to have_content(I18n.t("js.chat.settings.saved"))
          }.to change { channel_1.reload.auto_join_users }.from(false).to(true)
        end

        it "can change allow channel wide mentions" do
          chat_page.visit_channel_settings(channel_1)

          expect {
            find(".channel-settings-view__channel-wide-mentions-selector").click
            find(".channel-settings-view__channel-wide-mentions-selector [data-name='No']").click
            expect(page).to have_content(I18n.t("js.chat.settings.saved"))
          }.to change { channel_1.reload.allow_channel_wide_mentions }.from(true).to(false)
        end

        it "can close channel" do
          chat_page.visit_channel_settings(channel_1)

          expect {
            click_button(I18n.t("js.chat.channel_settings.close_channel"))
            find("#chat-channel-toggle-btn").click
            expect(page).to have_content(I18n.t("js.chat.channel_status.closed_header"))
          }.to change { channel_1.reload.status }.from("open").to("closed")
        end

        it "can delete channel" do
          chat_page.visit_channel_settings(channel_1)

          click_button(I18n.t("js.chat.channel_settings.delete_channel"))
          fill_in("channel-delete-confirm-name", with: channel_1.title)
          find_button("chat-confirm-delete-channel", disabled: false).click
          expect(page).to have_content(I18n.t("js.chat.channel_delete.process_started"))
        end

        context "when confirmation name is wrong" do
          it "doesn’t delete submission" do
            chat_page.visit_channel_settings(channel_1)
            find(".delete-btn").click
            fill_in("channel-delete-confirm-name", with: channel_1.title + "wrong")

            expect(page).to have_button("chat-confirm-delete-channel", disabled: true)
          end
        end
      end
    end
  end
end
