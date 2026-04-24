# frozen_string_literal: true

RSpec.describe "Admin dashboard" do
  fab!(:admin)

  before { enable_current_plugin }

  it "displays the sentiment dashboard" do
    SiteSetting.ai_sentiment_enabled = true
    sign_in(admin)

    visit "/admin/dashboard/sentiment"

    expect(page).to have_css(".section.sentiment")
  end

  it "displays the emotion table with links" do
    SiteSetting.ai_sentiment_enabled = true
    Fabricate(
      :sentiment_classification,
      target: Fabricate(:post),
      model_used: "SamLowe/roberta-base-go_emotions",
      classification: {
        love: 0.95,
      },
    )
    sign_in(admin)

    visit "/admin/dashboard/sentiment"

    expect(page).to have_css(".admin-report.emotion-love .cell.value.today-count a")
  end
end
