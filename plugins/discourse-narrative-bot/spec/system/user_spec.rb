# frozen_string_literal: true

describe "Narrative Bot PM", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:topics) { Fabricate.times(2, :post).map(&:topic) }
  fab!(:posts) { Fabricate.times(3, :post, topic: topics[0]) }

  context "when user tips are enabled" do
    before do
      Jobs.run_immediately!
      SiteSetting.enable_user_tips = true
      SiteSetting.discourse_narrative_bot_enabled = true
      # shortcut to generate welcome post since we're not going through user creation or first login
      user.enqueue_bot_welcome_post
    end

    it "does not delete the narrative bot PM when skipping all tips" do
      sign_in user
      visit "/"

      find(".fk-d-tooltip__content .user-tip__buttons .btn", text: "Skip tips").click
      expect(page).to have_no_css(".fk-d-tooltip__content .user-tip__title")

      expect(page).to have_css(".badge-notification.new-pms")

      find("#toggle-current-user").click

      expect(page).to have_css(".notification.unread.private-message", text: "Greetings!")
    end
  end
end
