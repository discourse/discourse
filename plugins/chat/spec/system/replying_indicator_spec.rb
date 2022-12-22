# frozen_string_literal: true

RSpec.describe "Replying indicator", type: :system, js: true do
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:current_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  let(:chat) { PageObjects::Pages::Chat.new }

  before do
    channel_1.add(current_user)
    channel_1.add(other_user)
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when on a channel" do
    context "when another user is replying" do
      xit "shows the replying indicator" do
        using_session(other_user.username) do
          sign_in(other_user)
          chat.visit_channel(channel_1)
          find(".chat-composer-input").fill_in(with: "hello there")
        end

        chat.visit_channel(channel_1)

        expect(page).to have_selector(
          ".chat-replying-indicator",
          text: I18n.t("js.chat.replying_indicator.single_user", username: other_user.username),
        )
      end
    end
  end
end
