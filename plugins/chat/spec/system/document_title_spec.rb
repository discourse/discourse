# frozen_string_literal: true

RSpec.describe "Document title", type: :system, js: true do
  fab!(:current_user) { Fabricate(:user) }

  let(:chat_page) { PageObjects::Pages::Chat.new }

  context "when visiting a public channel" do
    fab!(:channel_1) { Fabricate(:category_channel) }

    before do
      chat_system_bootstrap
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "shows the channel name in the document title" do
      chat_page.visit_channel(channel_1)

      expect(page.title).to start_with("##{channel_1.title}")
    end
  end

  context "when visiting a direct message channel" do
    fab!(:channel_1) { Fabricate(:direct_message_channel, users: [current_user]) }

    before do
      chat_system_bootstrap
      channel_1.add(current_user)
      sign_in(current_user)
    end

    it "shows the channel name in the document title" do
      chat_page.visit_channel(channel_1)

      expect(page.title).to start_with("#{channel_1.title(current_user)}")
    end
  end
end
