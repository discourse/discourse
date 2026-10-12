# frozen_string_literal: true

describe "Reviewable DSA classification" do
  fab!(:admin)
  fab!(:post)
  fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: post, potentially_illegal: true) }

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:form) { PageObjects::Components::FormKit.new(".reviewable-dsa-classification__form") }

  before do
    SiteSetting.enable_dsa_reporting = true
    sign_in(admin)
  end

  def choose_action(bundle, action)
    select_kit = PageObjects::Components::SelectKit.new(".dropdown-select-box.#{bundle}")
    select_kit.expand
    select_kit.select_row_by_value(action)
  end

  def reviewable_item
    find(".review-item[data-reviewable-id='#{reviewable.id}']")
  end

  it "doesn't offer classification before the flag is handled" do
    review_page.visit_reviewable(reviewable)

    expect(review_page).to have_css(".review-item__moderator-actions")
    expect(review_page).to have_no_css(".reviewable-dsa-classification")
  end

  it "doesn't offer classification when the flag is rejected" do
    visit("/review")
    choose_action("post-disagree", "post-disagree")

    expect(reviewable_item).to have_no_css(".review-item__moderator-actions")
    expect(reviewable_item).to have_no_css(".reviewable-dsa-classification")
  end

  it "keeps an upheld illegal flag in the queue until it's classified" do
    visit("/review")
    choose_action("post-agree-and-hide", "post-agree_and_keep")

    expect(form).to have_field_with_name("dsa_category")
    expect(reviewable_item).to have_no_css(".review-item__moderator-actions")

    visit("/review")
    expect(reviewable_item).not_to match_css(".reviewable-stale")

    form.field("dsa_category").select("STATEMENT_CATEGORY_SCAMS_AND_FRAUD")
    form.field("dsa_subcategory").select("KEYWORD_OTHER")
    form.field("dsa_subcategory_other").fill_in("Fake giveaway")
    form.submit

    summary =
      "#{I18n.t("js.review.dsa.legal_basis.decision_ground_illegal_content")} › #{I18n.t("js.review.dsa.categories.statement_category_scams_and_fraud")} › Fake giveaway"

    expect(reviewable_item).to have_css(".reviewable-dsa-classification__summary", text: summary)
    expect(reviewable_item).to have_css(".timeline-event__description", text: summary)

    visit("/review")
    expect(review_page).to have_no_css(".review-item[data-reviewable-id='#{reviewable.id}']")
  end

  it "handles upheld flags that aren't illegal as terms of service violations" do
    reviewable.update!(potentially_illegal: false)

    visit("/review")
    choose_action("post-agree-and-hide", "post-agree_and_keep")

    expect(form).to have_field_with_name("dsa_subcategory")
    expect(form.field("dsa_category")).to be_disabled
    expect(reviewable_item).to have_css(
      ".timeline-event__description",
      text: I18n.t("js.review.dsa.legal_basis.decision_ground_incompatible_content"),
    )
    expect(form.field("dsa_category")).to have_value("STATEMENT_CATEGORY_OTHER_VIOLATION_TC")
    expect(reviewable.reload).to have_attributes(
      legal_basis: "DECISION_GROUND_INCOMPATIBLE_CONTENT",
      dsa_category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
    )

    visit("/review")
    expect(review_page).to have_no_css(".review-item[data-reviewable-id='#{reviewable.id}']")

    review_page.visit_reviewable(reviewable)

    form.field("dsa_subcategory").select("KEYWORD_NUDITY")
    form.submit

    expect(review_page).to have_css(
      ".reviewable-dsa-classification__summary",
      text: I18n.t("js.review.dsa.keywords.keyword_nudity"),
    )
    expect(reviewable.reload).to have_attributes(
      legal_basis: "DECISION_GROUND_INCOMPATIBLE_CONTENT",
      dsa_category: "STATEMENT_CATEGORY_OTHER_VIOLATION_TC",
      dsa_subcategory: "KEYWORD_NUDITY",
    )
  end
end
