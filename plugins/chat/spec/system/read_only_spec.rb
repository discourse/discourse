# frozen_string_literal: true

RSpec.describe "Read only", type: :system do
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

    it "shows the read only status" do
      channel_1.read_only!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_content(I18n.t("js.chat.channel_status.read_only_header"))
    end

    it "disables the composer" do
      channel_1.read_only!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_field(
        placeholder: I18n.t("js.chat.placeholder_new_message_disallowed.read_only"),
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
      channel_1.read_only!(Discourse.system_user)
      chat.visit_channel_settings(channel_1)
      chat.visit_channel(channel_1)

      expect(page).to have_field(
        placeholder: I18n.t("js.chat.placeholder_new_message_disallowed.read_only"),
        disabled: true,
      )
    end
  end
end
