# frozen_string_literal: true

RSpec.describe "Applying a suggested review action" do
  fab!(:moderator)
  fab!(:post)
  fab!(:reviewable) do
    PostActionCreator.create(
      Fabricate(:user, trust_level: TrustLevel[3]),
      post,
      :inappropriate,
    ).reviewable
  end
  fab!(:decision_model)
  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    enable_current_plugin
    SiteSetting.ai_reviewable_action_suggestions_enabled = true
    SiteSetting.reviewable_claiming = "disabled"
    sign_in(moderator)
  end

  it "applies the suggested action from the queue" do
    AiReviewableSuggestion.create!(
      reviewable:,
      decision_model:,
      action_name: "post-agree_and_hide",
      confidence: 0.96,
    )
    visit("/review")
    action_label = I18n.t("reviewables.actions.agree_and_hide.title")
    button = find("button.ai-suggested-action", exact_text: action_label)
    expect(button["aria-label"]).to eq(
      I18n.t("js.discourse_ai.apply_review_suggestion", action: action_label),
    )
    button.click
    expect(review_page).to have_reviewable_with_problem_confirmed_status(reviewable)
    expect(post.reload).to be_hidden
    expect(page).to have_no_css("button.ai-suggested-action")
  end

  it "opens the editor for a suggestion that requires a staff edit" do
    AiReviewableSuggestion.create!(
      reviewable:,
      decision_model:,
      action_name: "post-agree_and_edit",
      confidence: 0.95,
    )
    review_page.visit_reviewable(reviewable)
    action_label = I18n.t("reviewables.actions.agree_and_edit.title")
    button = find("button.ai-suggested-action", exact_text: action_label)
    expect(button["aria-label"]).to eq(
      I18n.t("js.discourse_ai.apply_review_suggestion", action: action_label),
    )
    button.click
    expect(PageObjects::Components::Composer.new).to have_value(post.raw)
    expect(reviewable.reload).to be_pending
  end

  it "omits a stale action while keeping the available actions" do
    AiReviewableSuggestion.create!(
      reviewable:,
      decision_model:,
      action_name: "obsolete",
      confidence: 1.0,
    )
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_reviewable_action_dropdown
    expect(page).to have_no_css("button.ai-suggested-action")
  end
end
