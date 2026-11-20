# frozen_string_literal: true

RSpec.describe "Silenced user" do
  fab!(:channel_1, :category_channel)

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:channel) { PageObjects::Pages::ChatChannel.new }

  before { chat_system_bootstrap }

  context "when user is silenced" do
    fab!(:silenced_user, :user)

    before do
      UserSilencer.silence(silenced_user)
      channel_1.add(silenced_user)
      sign_in(silenced_user)
      chat.visit_channel(channel_1)
    end

    it "disables the composer" do
      chat.visit_channel(channel_1)

      expect(page).to have_field(
        placeholder: I18n.t("js.chat.placeholder_silenced"),
        disabled: true,
      )
    end

    it "disables the send button" do
      chat.visit_channel(channel_1)

      expect(page).to have_css(".chat-composer-button.-send[disabled]")
    end

    it "prevents reactions" do
      message_1 = Fabricate(:chat_message, chat_channel: channel_1)
      chat.visit_channel(channel_1)
      channel.hover_message(message_1)

      expect(page).to have_css(".chat-message-actions")
      expect(page).to have_no_css(".chat-message-actions .react-btn")
      expect(page).to have_no_css(".chat-message-actions .reply-btn")
    end

    it "allows flagging messages as illegal when allow_all_users_to_flag_illegal_content is enabled" do
      SiteSetting.email_address_to_report_illegal_content = "illegal@example.com"
      SiteSetting.allow_all_users_to_flag_illegal_content = true
      message_1 = Fabricate(:chat_message, chat_channel: channel_1)
      flag_modal = PageObjects::Modals::Flag.new

      chat.visit_channel(channel_1)
      channel.messages.flag(message_1)

      expect(flag_modal).to have_choices(I18n.t("js.flagging.formatted_name.illegal"))

      flag_modal.choose_type(:illegal)
      flag_modal.fill_message("This looks totally illegal to me.")
      flag_modal.check_confirmation
      flag_modal.confirm_flag

      expect(channel.message_by_id(message_1.id)).to have_css(".chat-message-info__flag")
    end
  end
end
