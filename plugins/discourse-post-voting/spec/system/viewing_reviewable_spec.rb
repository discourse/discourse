# frozen_string_literal: true

describe "Viewing reviewable post voting comment", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:reply) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, post: reply) }
  fab!(:reviewable) { Fabricate(:reviewable_post_voting_comment, target: comment, topic: topic) }
  let(:review_page) { PageObjects::Pages::Review.new }

  before do
    group.add(admin)
    sign_in(admin)
  end

  it "has created at history item" do
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_history_items(count: 2)
    expect(review_page).to have_created_at_history_item
  end

  xit "Allows to delete and restore comment" do
    review_page.visit_reviewable(reviewable)

    expect(page).to have_text(comment.raw)

    review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_delete")
    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    review_page.visit_reviewable(reviewable)
    expect(page).not_to have_text(comment.raw)

    review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_restore")
    expect(review_page).to have_reviewable_with_approved_status(reviewable)
    expect(page).to have_text(comment.raw)

    review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_delete")
    review_page.select_bundled_action(reviewable, "post_voting_comment-disagree_and_restore")
    expect(review_page).to have_reviewable_with_rejected_status(reviewable)
  end

  xit "Allows to ignore the reviewable" do
    review_page.visit_reviewable(reviewable)

    review_page.select_bundled_action(reviewable, "post_voting_comment-no_action_comment")
    expect(review_page).to have_reviewable_with_rejected_status(reviewable)
  end

  xit "Allows to keep comment" do
    review_page.visit_reviewable(reviewable)

    review_page.select_bundled_action(reviewable, "post_voting_comment-agree_and_keep_comment")
    expect(review_page).to have_reviewable_with_approved_status(reviewable)
  end
end
