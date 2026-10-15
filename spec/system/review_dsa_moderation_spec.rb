# frozen_string_literal: true

describe "Classifying reviewable moderation" do
  fab!(:admin)
  fab!(:topic, :topic_with_op)

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:modal) { PageObjects::Modals::DsaModeration.new }
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

  it "classifies direct post actions at confirmation and preserves pending reviews on cancel" do
    { "delete_and_agree" => "Delete post", "agree_and_hide" => "Hide post" }.each do |action, label|
      post = Fabricate(:post, topic: topic)
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: post,
          target_created_by: post.user,
          topic: topic,
        )
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-#{action}", bundle_index: 1)

      expect(modal).to have_action_title(label)
      expect(modal).to have_classification
      modal.cancel
      expect(modal).to be_closed
      expect(review_page).to have_reviewable_with_pending_status(reviewable)

      review_page.select_bundled_action(reviewable, "post-#{action}", bundle_index: 1)
      modal.confirm(label)
      expect(modal).to have_required_errors
      modal.select_rule(rule[:ground])
      modal.select_category(category)
      modal.confirm(label)

      expect(modal).to be_closed
      expect(review_page).to have_reviewable_with_approved_status(reviewable)
      expect(review_page).to have_note(note)
      page.refresh
      expect(review_page).to have_note(note)
    end
  end

  it "keeps author penalties in one modal and preserves classification when going back" do
    { "suspend" => "Suspend", "silence" => "Silence" }.each do |penalty, label|
      post = Fabricate(:post, topic: topic)
      reviewable =
        Fabricate(
          :reviewable_flagged_post,
          target: post,
          target_created_by: post.user,
          topic: topic,
        )
      penalty_modal = PageObjects::Modals::PenalizeUser.new(penalty)
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-agree_and_#{penalty}", bundle_index: 1)

      expect(modal).to have_action_title("#{label} @#{post.user.username}")
      penalty_modal.set_future_date("two_weeks")
      modal.continue
      expect(modal).to have_action_title("#{label} @#{post.user.username}")
      expect(modal).to have_classification
      modal.select_rule(rule[:ground])
      modal.select_category(category)
      modal.back
      expect(modal).to have_action_title("#{label} @#{post.user.username}")
      modal.continue
      expect(modal).to have_selected_category(category)
      modal.confirm("#{label} and delete post")

      expect(modal).to be_closed
      expect(review_page).to have_reviewable_with_approved_status(reviewable)
      page.refresh
      expect(review_page).to have_note(note)
    end
  end
end
