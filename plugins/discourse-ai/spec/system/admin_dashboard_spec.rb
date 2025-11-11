# frozen_string_literal: true

RSpec.describe "Admin dashboard", type: :system do
  fab!(:admin)

  before { enable_current_plugin }

  xit "displays the sentiment dashboard" do
    SiteSetting.ai_sentiment_enabled = true
    sign_in(admin)

    visit "/admin"
    find(".navigation-item.sentiment").click()

    expect(page).to have_css(".section.sentiment")
  end

  xit "displays the emotion table with links" do
    SiteSetting.ai_sentiment_enabled = true
    sign_in(admin)

    visit "/admin"
    find(".navigation-item.sentiment").click()

    expect(page).to have_css(".admin-report.emotion-love .cell.value.today-count a")
  end
end
