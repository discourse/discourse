# frozen_string_literal: true
RSpec.describe "Record reviewable restrictions" do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  let!(:reviewable) { PostActionCreator.inappropriate(flagger, post).reviewable }
  let(:review_page) { PageObjects::Pages::Review.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  it "lets moderators finish a review without another classification step" do
    sign_in(admin)
    settings_page.visit("dsa_reporting_enabled")
    expect(page).to have_no_css(settings_page.setting_row_selector("dsa_reporting_enabled"))
    SiteSetting.dsa_reporting_enabled = true
    page.visit("/review")

    review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)

    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    page.refresh
    expect(review_page).to have_reviewable_items(count: 0)
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_reviewable_with_approved_status(reviewable)
  end
end
