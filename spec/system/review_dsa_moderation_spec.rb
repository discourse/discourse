# frozen_string_literal: true

describe "Classifying reviewable moderation" do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:modal) { PageObjects::Modals::DsaModeration.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:rule) { { ground: "Be respectful", explanation: "Personal attacks are not allowed." } }
  let(:category) { "Other violation of terms and conditions" }

  let(:note) do
    "Classified this moderation decision for DSA reporting. Community rule: #{rule[:ground]} Category: #{category}"
  end

  before do
    SiteSetting.dsa_reporting_enabled = true
    SiteSetting.dsa_community_rules = [rule].to_json
    sign_in(admin)
  end

  it "preserves suspension details and classification when navigating back, and leaves the review pending if cancelled" do
    post = Fabricate(:post, topic: topic)
    reviewable =
      Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user, topic: topic)
    penalty_modal = PageObjects::Modals::PenalizeUser.new("suspend")

    review_page.visit_reviewable(reviewable)
    review_page.select_bundled_action(reviewable, "post-agree_and_suspend", bundle_index: 1)

    expect(modal).to have_action_title("Suspend User")
    expect(modal).to have_cancel_button

    penalty_modal.set_future_date("two_weeks")

    expect(modal).to have_disabled_continue

    penalty_modal.fill_in_suspend_reason("Repeated personal attacks.")
    modal.continue

    expect(modal).to have_action_title("Suspend User")
    expect(modal).to have_classification
    expect(modal).to have_focused_step("DSA classification")
    expect(modal).to have_no_cancel_button

    modal.confirm("Suspend")

    expect(modal).to have_required_errors

    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.close
    dialog = PageObjects::Components::Dialog.new

    expect(dialog).to be_open

    dialog.click_no

    expect(modal).to have_selected_category(category)

    modal.back

    expect(modal).to have_focused_step("Action details")
    expect(modal).to have_action_title("Suspend User")
    expect(penalty_modal).to have_suspend_reason("Repeated personal attacks.")

    modal.continue

    expect(modal).to have_selected_category(category)

    modal.close

    expect(dialog).to be_open

    dialog.click_yes

    expect(modal).to be_closed
    expect(review_page).to have_reviewable_with_pending_status(reviewable)
    expect(review_page).to have_no_note(note)

    review_page.select_bundled_action(reviewable, "post-agree_and_suspend", bundle_index: 1)
    penalty_modal.set_future_date("two_weeks")
    penalty_modal.fill_in_suspend_reason("Repeated personal attacks.")
    modal.continue
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Suspend")

    expect(modal).to be_closed
    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    page.refresh

    expect(review_page).to have_note(note)

    admin_user_page = PageObjects::Pages::AdminUser.new
    admin_user_page.visit(post.user)

    expect(admin_user_page).to have_suspension_reason("Repeated personal attacks.")
  end

  it "classifies before editing, handling the review only after the edit is saved" do
    post = topic.first_post
    reviewable =
      Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user, topic:)

    review_page.visit_reviewable(reviewable)
    review_page.select_bundled_action(reviewable, "post-agree_and_edit", bundle_index: 1)

    expect(modal).to have_action_title("DSA classification")

    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Continue to editor")

    expect(modal).to be_closed
    expect(composer).to be_opened

    composer.fill_content("A correction that should be discarded.")
    composer.discard
    discard_modal = PageObjects::Modals::DiscardDraft.new

    expect(discard_modal).to be_open

    discard_modal.click_discard

    expect(composer).to be_closed
    expect(review_page).to have_reviewable_with_pending_status(reviewable)
    expect(review_page).to have_no_note(note)

    review_page.select_bundled_action(reviewable, "post-agree_and_edit", bundle_index: 1)
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Continue to editor")

    expect(composer).to be_opened

    composer.fill_content("A corrected contribution to the discussion.")
    composer.submit

    expect(composer).to be_closed
    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    page.refresh

    expect(review_page).to have_note(note)
  end
end
