# frozen_string_literal: true

RSpec.describe "Reply to message - thread - full page", type: :system, js: true do
  let(:chat_page) { PageObjects::Pages::Chat.new }

  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:category_channel) }
end
