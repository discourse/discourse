# frozen_string_literal: true

describe "Viewing reviewable post voting comment", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:reply) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, post: reply) }
  fab!(:reviewable) { Fabricate(:reviewable_post_voting_comment, target: comment, topic: topic) }
  let(:refreshed_review_page) { PageObjects::Pages::RefreshedReview.new }

  before do
    SiteSetting.reviewable_ui_refresh = group.name
    group.add(admin)
    sign_in(admin)
  end

  it "Allows to delete and restore comment" do
    refreshed_review_page.visit_reviewable(reviewable)

    expect(page).to have_text(comment.raw)

    refreshed_review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_delete")
    expect(refreshed_review_page).to have_reviewable_with_approved_status(reviewable)

    refreshed_review_page.visit_reviewable(reviewable)
    expect(page).not_to have_text(comment.raw)

    refreshed_review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_restore")
    expect(refreshed_review_page).to have_reviewable_with_approved_status(reviewable)
    expect(page).to have_text(comment.raw)

    refreshed_review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_delete")
    refreshed_review_page.select_bundled_action(
      reviewable,
      "post_voting_comment-disagree_and_restore",
    )
    expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)
  end

  it "Allows to ignore the reviewable" do
    refreshed_review_page.visit_reviewable(reviewable)

    refreshed_review_page.select_bundled_action(reviewable, "post_voting_comment-no_action_comment")
    expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)
  end

  it "Allows to keep comment" do
    refreshed_review_page.visit_reviewable(reviewable)

    refreshed_review_page.select_bundled_action(
      reviewable,
      "post_voting_comment-agree_and_keep_comment",
    )
    expect(refreshed_review_page).to have_reviewable_with_approved_status(reviewable)
  end
end
