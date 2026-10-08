# frozen_string_literal: true
RSpec.describe "Classify a reviewable DSA statement" do
  fab!(:admin)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  let!(:reviewable) { PostActionCreator.inappropriate(flagger, post).reviewable }
  let(:review_page) { PageObjects::Pages::Review.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }
  let(:classification) { PageObjects::Components::DsaClassification.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  it "lets staff finish moderation and return to classify using two choices" do
    sign_in(admin)
    settings_page.visit("dsa_reporting_enabled")
    expect(settings_page).to have_setting("dsa_reporting_enabled")
    expect(settings_page.bool_setting_checkbox("dsa_reporting_enabled")).not_to be_checked
    settings_page.toggle_bool_setting("dsa_reporting_enabled")

    page.visit("/review")
    review_page.select_bundled_action(reviewable, "post-delete_and_agree", bundle_index: 1)

    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    expect(classification).to have_classification_form

    page.visit("/review")
    expect(classification).to have_unfinished_reviewable(reviewable)
    classification.visit_unfinished
    expect(classification).to have_unfinished_reviewable(reviewable)
    review_page.visit_reviewable(reviewable)
    expect(classification).to have_classification_form

    classification.classify(community_rule: "No personal attacks", category: "Cyber violence")

    expect(toasts).to have_success("Classification saved")
    expect(classification).to have_timeline_focus
    expect(classification).to have_no_classification_form
    expect(classification).to have_completion_note(
      community_rule: "No personal attacks",
      category: "Cyber violence",
    )

    page.refresh
    expect(classification).to have_no_classification_form
    expect(classification).to have_completion_note(
      community_rule: "No personal attacks",
      category: "Cyber violence",
    )

    classification.visit_unfinished
    expect(review_page).to have_reviewable_items(count: 0)

    Jobs::SubmitDsaStatements.new.execute({})
    page.visit("/review")
    within(".reviewable-filter:first-child") do
      PageObjects::Components::SelectKit.new(".select-kit").select_row_by_name("Submission failed")
    end
    click_button("Refresh")
    expect(page).to have_content("Configure")
    review_page.visit_reviewable(reviewable)
    within(".dsa-classification") { click_button("Edit classification") }
    expect(classification).to have_classification_form
    classification.classify(community_rule: "No abusive content", category: "Cyber violence")
    expect(toasts).to have_success("Classification saved")
    expect(classification).to have_no_classification_form
    Jobs::SubmitDsaStatements.new.execute({})
    page.refresh
    within(".dsa-classification") { click_button("Retry submission") }
    expect(toasts).to have_success("Submission queued")
    expect(classification).to have_no_classification_form
  end
end
