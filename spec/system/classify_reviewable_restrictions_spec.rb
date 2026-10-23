# frozen_string_literal: true

RSpec.describe "Classifying restrictive reviewable actions" do
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
    SiteSetting.contact_email = "support@forum.example"
    sign_in(admin)
  end

  it "lets staff classify account deletion and cancel without deleting the account" do
    user = Fabricate(:user)
    flagger = Fabricate(:user, trust_level: TrustLevel[3])
    post = Fabricate(:post, topic:, user:)
    reviewable = PostActionCreator.spam(flagger, post).reviewable

    review_page.visit_reviewable(reviewable)
    review_page.select_bundled_action(reviewable, "post-delete_user_block", bundle_index: 1)
    expect(modal).to have_action_title("Delete and block user")
    expect(modal).to have_no_confirmation_prompt
    expect(modal).to have_classification
    modal.cancel
    expect(review_page).to have_reviewable_with_pending_status(reviewable)

    review_page.select_bundled_action(reviewable, "post-delete_user_block", bundle_index: 1)
    modal.confirm("Delete and block user")
    expect(modal).to have_required_errors
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Delete and block user")
    expect(modal).to be_closed
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_note(note)
    page.refresh
    expect(review_page).to have_note(note)
  end

  it "lets staff classify submission rejection and deletion through review every post" do
    queued = Fabricate(:reviewable_queued_post_topic)
    review_page.visit_reviewable(queued)
    review_page.select_bundled_action(queued, "reject_post")
    expect(modal).to have_action_title("Reject Post")
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Reject Post")
    expect(modal).to be_closed
    expect(review_page).to have_reviewable_with_rejected_status(queued)
    page.refresh
    expect(review_page).to have_note(note)

    post = Fabricate(:post, topic:)
    reviewable = ReviewablePost.queue_for_review(post)
    review_page.visit_reviewable(reviewable)
    review_page.select_bundled_action(reviewable, "post-reject_and_delete")
    expect(modal).to have_action_title("Reject and Delete the post")
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Reject and Delete the post")
    expect(modal).to be_closed
    page.refresh
    expect(review_page).to have_note(note)
  end

  it "lets staff classify avatar removal" do
    user = Fabricate(:user, uploaded_avatar: Fabricate(:upload))
    reviewable = Fabricate(:suspect_user_reviewable, target: user)
    review_page.visit_reviewable(reviewable)
    review_page.select_action(reviewable, "user-remove_avatar")
    expect(modal).to have_action_title("Remove avatar")
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Remove avatar")
    expect(modal).to be_closed
    expect(review_page).to have_reviewable_with_pending_status(reviewable)
    page.refresh
    expect(review_page).to have_note(note)
  end

  it "keeps the registration rejection reason and optional email when DSA is enabled" do
    SiteSetting.must_approve_users = true
    registration = Fabricate(:reviewable_user, target: Fabricate(:user, approved: false))
    rejection_modal = PageObjects::Modals::RejectReasonReviewable.new
    reason = "Membership is limited to employees."

    review_page.visit_reviewable(registration)
    review_page.select_bundled_action(registration, "user-delete_user_block")
    rejection_modal.fill_in_rejection_reason(reason)
    rejection_modal.select_send_rejection_email_checkbox
    rejection_modal.delete_user

    expect(review_page).to have_reviewable_with_rejected_status(registration)
    expect(registration.reload.reject_reason).to eq(reason)
    expect(registration.dsa_statement_of_records).to be_empty
  end

  it "lets staff classify account and submission penalties without a nonexistent post action" do
    suspect = Fabricate(:suspect_user_reviewable)
    review_page.visit_reviewable(suspect)
    review_page.select_bundled_action(suspect, "user-silence_user")
    expect(modal).to have_action_title("Silence @#{suspect.target.username}")
    PageObjects::Modals::PenalizeUser.new("silence").set_future_date("two_weeks")
    modal.continue
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Silence")
    expect(modal).to be_closed
    page.refresh
    expect(review_page).to have_note(note)

    queued = Fabricate(:reviewable_queued_post_topic)
    review_page.visit_reviewable(queued)
    review_page.select_bundled_action(queued, "reject_and_suspend")
    expect(modal).to have_action_title(
      "Reject post and suspend @#{queued.target_created_by.username}",
    )
    penalty_modal = PageObjects::Modals::PenalizeUser.new("suspend")
    penalty_modal.fill_in_suspend_reason("Repeated personal attacks.")
    penalty_modal.set_future_date("two_weeks")
    modal.continue
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Reject and suspend user")
    expect(modal).to be_closed
    page.refresh
    expect(review_page).to have_note(note)
  end

  it "lets staff classify a first post edit and remove the last topic tag" do
    SiteSetting.tagging_enabled = true
    tag = Fabricate(:tag)
    topic.update!(tags: [tag])
    post = topic.first_post
    reviewable =
      Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user, topic:)
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_content(tag.name)
    review_page.select_bundled_action(reviewable, "post-agree_and_edit", bundle_index: 1)
    expect(modal).to have_action_title("Edit post")
    modal.select_rule(rule[:ground])
    modal.select_category(category)
    modal.confirm("Continue to editor")
    expect(modal).to be_closed
    expect(composer).to be_opened
    tag_chooser = PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
    tag_chooser.expand
    tag_chooser.unselect_by_name(tag.name)
    tag_chooser.collapse_with_escape
    composer.fill_content("A corrected contribution to the discussion.")
    composer.submit
    expect(composer).to be_closed
    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    page.refresh
    expect(review_page).to have_note(note)
    expect(review_page).to have_no_content(tag.name)
  end
end
