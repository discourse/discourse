# frozen_string_literal: true

RSpec.describe "Bulk applying suggested review actions" do
  fab!(:moderator)
  fab!(:decision_model)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[3]) }
  fab!(:hidden_post, :post)
  fab!(:kept_post, :post)
  fab!(:skipped_post, :post)
  fab!(:edited_post, :post)

  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    enable_current_plugin
    SiteSetting.ai_reviewable_action_suggestions_enabled = true
    SiteSetting.reviewable_claiming = "disabled"
    sign_in(moderator)
  end

  def flag(post, action_name)
    reviewable = PostActionCreator.create(flagger, post, :inappropriate).reviewable
    AiReviewableSuggestion.create!(reviewable:, decision_model:, action_name:, confidence: 0.96)
    reviewable
  end

  def row(reviewable)
    ".ai-review-bulk__row[data-reviewable-id='#{reviewable.id}']"
  end

  it "applies the selected suggestions and leaves the rest pending" do
    hidden = flag(hidden_post, "post-agree_and_hide")
    kept = flag(kept_post, "post-disagree")
    skipped = flag(skipped_post, "post-agree_and_hide")
    edited = flag(edited_post, "post-agree_and_edit")

    visit("/review")
    find(".ai-review-bulk-nav-item a").click

    expect(page).to have_css("#{row(edited)} .ai-review-bulk__checkbox:disabled")
    expect(page).to have_css(
      "#{row(edited)} .ai-review-bulk__open[href='/review/#{edited.id}']" \
        "[aria-label='#{I18n.t("js.discourse_ai.review_bulk.blocked.needs_input")}']",
    )

    find("#{row(skipped)} .ai-review-bulk__checkbox").click
    find(".ai-review-bulk__apply").click
    dialog.click_yes

    applied = I18n.t("js.discourse_ai.review_bulk.status.applied")
    expect(page).to have_css("#{row(hidden)} .ai-review-bulk__status", text: applied)
    expect(page).to have_css("#{row(kept)} .ai-review-bulk__status", text: applied)
    expect(page).to have_no_css("#{row(skipped)} .ai-review-bulk__status", text: applied)

    expect(hidden_post.reload).to be_hidden
    expect(hidden.reload).to be_approved
    expect(kept.reload).to be_rejected
    expect(skipped.reload).to be_pending
    expect(edited.reload).to be_pending
  end
end
