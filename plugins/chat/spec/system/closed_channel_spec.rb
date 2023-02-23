# frozen_string_literal: true

RSpec.describe "Closed channel", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when regular user" do
    fab!(:current_user) { Fabricate(:user) }

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "shows the closed status" do
      channel_1.closed!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_content(I18n.t("js.chat.channel_status.closed_header"))
    end

    it "disables the composer" do
      channel_1.closed!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_field(
        placeholder: I18n.t("js.chat.placeholder_new_message_disallowed.closed"),
        disabled: true,
      )
    end
  end

  context "when admin" do
    fab!(:current_user) { Fabricate(:admin) }

    before do
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "disables the composer" do
      channel_1.closed!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_no_field(
        placeholder: I18n.t("js.chat.placeholder_new_message_disallowed.closed"),
        disabled: true,
      )
    end
  end
end
