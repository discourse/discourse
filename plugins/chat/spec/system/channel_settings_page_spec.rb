# frozen_string_literal: true

RSpec.describe "Channel - Info - Settings page", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:channel_settings_page) { PageObjects::Pages::ChatChannelSettings.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when visiting from browse page" do
    context "when clicking back button" do
      it "redirects to browse page" do
        chat_page.visit_browse
        find(".c-navbar__back-button").click

        expect(page).to have_current_path("/chat/browse/open")
      end
    end
  end

  context "when visiting from channel page" do
    context "when clicking back button" do
      it "redirects to channel page" do
        chat_page.visit_channel(channel_1)
        find(".c-navbar__channel-title").click
        find(".c-navbar__back-button").click

        expect(page).to have_current_path(chat.channel_path(channel_1.slug, channel_1.id))
      end
    end
  end

  context "as unauthorized user" do
    before { SiteSetting.chat_allowed_groups = Fabricate(:group).id }

    it "redirects to home page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/latest")
    end
  end

  context "as not allowed to see the channel" do
    fab!(:channel_1) { Fabricate(:private_category_channel) }

    it "redirects to browse page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/chat/browse/open")
    end
  end

  context "as not member of channel" do
    it "shows settings page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings")
    end
  end

  context "as regular user of channel" do
    before { channel_1.add(current_user) }

    it "shows settings page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings")
    end

    it "shows channel info" do
      chat_page.visit_channel_settings(channel_1)

      expect(page.find(".badge-category__name")).to have_content(channel_1.chatable.name)
      expect(page.find(".c-channel-settings__name")).to have_content(channel_1.title)
      expect(page.find(".c-channel-settings__slug")).to have_content(channel_1.slug)
    end

    it "can’t edit name or slug" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_no_selector(".edit-name-slug-btn")
    end

    it "can’t edit description" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_no_selector(".edit-description-btn")
    end

    it "escapes channel title" do
      channel_1.update!(name: "<script>alert('hello')</script>")
      chat_page.visit_channel_settings(channel_1)

      expect(page.find(".c-channel-settings__name")["innerHTML"].strip).to eq(
        "&lt;script&gt;alert('hello')&lt;/script&gt;",
      )
      expect(page.find(".chat-channel-name__label")["innerHTML"].strip).to include(
        "&lt;script&gt;alert('hello')&lt;/script&gt;",
      )
    end

    it "is not showing admin section" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_no_css("[data-section='admin']")
    end

    it "can mute channel" do
      chat_page.visit_channel_settings(channel_1)
      membership = channel_1.membership_for(current_user)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__mute-switch").toggle

        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.muted }.from(false).to(true)
    end

    it "can change notification level" do
      chat_page.visit_channel_settings(channel_1)
      membership = channel_1.membership_for(current_user)

      expect {
        select_kit =
          PageObjects::Components::SelectKit.new(".c-channel-settings__notifications-selector")
        select_kit.expand
        select_kit.select_row_by_name("Never")

        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { membership.reload.notification_level }.from("mention").to("never")
    end

    it "can unfollow channel" do
      membership = channel_1.membership_for(current_user)

      chat_page.visit_channel_settings(channel_1)
      click_button(I18n.t("js.chat.channel_settings.leave_channel"))

      expect(page).to have_current_path("/chat/browse/open")
      expect(membership.reload.following).to eq(false)
    end

    context "when group channel" do
      fab!(:channel_1) do
        Fabricate(:direct_message_channel, group: true, users: [current_user, Fabricate(:user)])
      end

      before { channel_1.add(current_user) }

      it "can leave channel" do
        membership = channel_1.membership_for(current_user)

        chat_page.visit_channel_settings(channel_1)
        click_button(I18n.t("js.chat.channel_settings.leave_channel"))

        expect(page).to have_current_path("/chat/browse/open")
        expect(Chat::UserChatChannelMembership.exists?(membership.id)).to eq(false)
        expect(
          channel_1.chatable.direct_message_users.where(user_id: current_user.id).exists?,
        ).to eq(false)
      end
    end

    context "when direct message channel" do
      fab!(:channel_1) do
        Fabricate(:direct_message_channel, users: [current_user, Fabricate(:user)])
      end

      before { channel_1.add(current_user) }

      it "can toggle threading" do
        chat_page.visit_channel_settings(channel_1)

        expect {
          PageObjects::Components::DToggleSwitch.new(".c-channel-settings__threading-switch").toggle
          expect(toasts).to have_success(I18n.t("js.saved"))
        }.to change { channel_1.reload.threading_enabled }.from(true).to(false)
      end
    end
  end

  context "as staff" do
    fab!(:current_user) { Fabricate(:admin) }

    before { channel_1.add(current_user) }

    it "can edit name" do
      chat_page.visit_channel_settings(channel_1)

      edit_modal = channel_settings_page.open_edit_modal

      expect(edit_modal).to have_name_input(channel_1.title)

      name = "A new name"

      edit_modal.fill_and_save_name(name)

      expect(page).to have_content(name)
    end

    it "can edit description" do
      chat_page.visit_channel_settings(channel_1)
      find(".edit-description-btn").click

      expect(page).to have_selector(
        ".chat-modal-edit-channel-description__description-input",
        text: channel_1.description,
      )

      description = "A new description"
      find(".chat-modal-edit-channel-description__description-input").fill_in(with: description)
      find(".create").click

      expect(page).to have_content(description)
    end

    it "can edit slug" do
      chat_page.visit_channel_settings(channel_1)

      edit_modal = channel_settings_page.open_edit_modal

      slug = "gonzo-slug"

      expect(edit_modal).to have_slug_input(channel_1.slug)

      edit_modal.fill_and_save_slug(slug)

      expect(page).to have_current_path("/chat/c/gonzo-slug/#{channel_1.id}")
    end

    it "can clear the slug to use the autogenerated version based on the name" do
      channel_1.update!(name: "test channel")
      chat_page.visit_channel_settings(channel_1)
      edit_modal = channel_settings_page.open_edit_modal

      expect(edit_modal).to have_slug_input(channel_1.slug)

      edit_modal.fill_in_slug_input("")
      edit_modal.wait_for_auto_generated_slug
      edit_modal.save_changes

      expect(page).to have_current_path("/chat/c/test-channel/#{channel_1.id}")
    end

    it "shows settings page" do
      chat_page.visit_channel_settings(channel_1)

      expect(page).to have_current_path("/chat/c/#{channel_1.slug}/#{channel_1.id}/info/settings")
    end

    it "can change auto join setting" do
      chat_page.visit_channel_settings(channel_1)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__auto-join-switch").toggle
        find("#dialog-holder .btn-primary").click

        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { channel_1.reload.auto_join_users }.from(false).to(true)
    end

    it "can change allow channel wide mentions" do
      chat_page.visit_channel_settings(channel_1)

      expect {
        PageObjects::Components::DToggleSwitch.new(
          ".c-channel-settings__channel-wide-mentions",
        ).toggle

        expect(toasts).to have_success(I18n.t("js.saved"))
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

    it "can enable threading" do
      chat_page.visit_channel_settings(channel_1)

      expect {
        PageObjects::Components::DToggleSwitch.new(".c-channel-settings__threading-switch").toggle

        expect(toasts).to have_success(I18n.t("js.saved"))
      }.to change { channel_1.reload.threading_enabled }.from(false).to(true)
    end

    it "can delete channel" do
      chat_page.visit_channel_settings(channel_1)

      click_button(I18n.t("js.chat.channel_settings.delete_channel"))
      fill_in("channel-delete-confirm-name", with: channel_1.title)
      find_button("chat-confirm-delete-channel", disabled: false).click
      expect(page).to have_content(I18n.t("js.chat.channel_delete.process_started"))
    end

    it "doesn’t delete when confirmation is wrong" do
      chat_page.visit_channel_settings(channel_1)
      find(".delete-btn").click
      fill_in("channel-delete-confirm-name", with: channel_1.title + "wrong")

      expect(page).to have_button("chat-confirm-delete-channel", disabled: true)
    end
  end
end
