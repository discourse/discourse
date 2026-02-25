# frozen_string_literal: true

RSpec.describe "Archived channel settings", type: :system do
  fab!(:channel_1, :chat_channel)
  fab!(:current_user, :admin)

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    chat_system_bootstrap
    SiteSetting.chat_allow_archiving_channels = true
    channel_1.add(current_user)
    sign_in(current_user)
  end

  context "when channel is archived" do
    before { channel_1.update!(status: :archived) }

    it "shows a disabled open channel button with a tooltip" do
      chat.visit_channel_settings(channel_1)

      expect(page).to have_css(".open-btn[disabled]")
      expect(page).to have_no_css(".close-btn")

      find(".open-btn").hover
      expect(page).to have_content(
        I18n.t("js.chat.channel_settings.open_channel_disabled_archived"),
      )
    end

    it "does not show the archive channel button" do
      chat.visit_channel_settings(channel_1)

      expect(page).to have_no_content(I18n.t("js.chat.channel_settings.archive_channel"))
    end
  end

  context "when channel is read-only" do
    before { channel_1.update!(status: :read_only) }

    it "shows a disabled open channel button with a tooltip" do
      chat.visit_channel_settings(channel_1)

      expect(page).to have_css(".open-btn[disabled]")
      expect(page).to have_no_css(".close-btn")

      find(".open-btn").hover
      expect(page).to have_content(
        I18n.t("js.chat.channel_settings.open_channel_disabled_read_only"),
      )
    end
  end
end
