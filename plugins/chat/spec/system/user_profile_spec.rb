# frozen_string_literal: true

RSpec.describe "User profile", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user)

  before do
    user.user_stat.update!(post_count: 1)
    chat_system_bootstrap
  end

  shared_examples "not showing chat button" do
    it "has no chat button" do
      expect(page).to have_no_css(".chat-direct-message-btn")
    end
  end

  shared_examples "showing chat button" do
    it "shows the chat button" do
      expect(page).to have_css(".chat-direct-message-btn")
    end
  end

  def visit_user_profile
    visit("/u/" + user.username + "/summary")
  end

  context "when user" do
    context "with chat disabled" do
      before do
        SiteSetting.chat_enabled = false
        sign_in(current_user)
        visit_user_profile
      end

      include_examples "not showing chat button"
    end

    context "with chat enabled" do
      before do
        sign_in(current_user)
        visit_user_profile
      end

      include_examples "showing chat button"
    end
  end

  context "when anonymous" do
    before { visit_user_profile }

    include_examples "not showing chat button"
  end
end
