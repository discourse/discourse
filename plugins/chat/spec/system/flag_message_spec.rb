# frozen_string_literal: true

RSpec.describe "Flag message" do
  fab!(:current_user, :user)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when category channel" do
    fab!(:category_channel_1, :category_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }

    before { category_channel_1.add(current_user) }

    it "allows to flag a message" do
      chat.visit_channel(category_channel_1)
      channel.messages.flag(message_1)

      expect(page).to have_css(".flag-modal")

      choose("radio_spam")
      click_button(I18n.t("js.chat.flagging.action"))

      expect(channel.message_by_id(message_1.id)).to have_css(".chat-message-info__flag")
    end
  end

  context "when direct message channel" do
    fab!(:dm_channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: dm_channel_1) }

    it "allows to flag a message" do
      chat.visit_channel(dm_channel_1)
      channel.expand_message_actions(message_1)

      expect(page).to have_css("[data-value='flag']")
    end
  end

  context "when user is outside the flag allowed groups" do
    fab!(:category_channel_1, :category_channel)
    fab!(:message_1) { Fabricate(:chat_message, chat_channel: category_channel_1) }
    let(:flag_modal) { PageObjects::Modals::Flag.new }

    before do
      SiteSetting.chat_message_flag_allowed_groups = ""
      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      category_channel_1.add(current_user)
    end

    it "only allows flagging as illegal" do
      chat.visit_channel(category_channel_1)
      channel.messages.flag(message_1)

      expect(flag_modal).to have_choices(I18n.t("js.flagging.formatted_name.illegal"))
    end
  end
end
