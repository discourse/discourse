# frozen_string_literal: true

describe "Viewing reviewable post voting comment" do
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

  it "has the created_at history item" do
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_history_items(count: 2)
    expect(review_page).to have_created_at_history_item
  end

  it "allows to agree with the flag and delete the comment" do
    review_page.visit_reviewable(reviewable)
    expect(page).to have_text(comment.raw)

    review_page.select_bundled_action(
      reviewable,
      "post_voting_comment-agree_and_delete",
      bundle_index: 1,
    )
    expect(review_page).to have_reviewable_with_approved_status(reviewable)

    review_page.visit_reviewable(reviewable)
    expect(page).not_to have_text(comment.raw)
  end

  it "allows to agree with the flag and keep the comment" do
    review_page.visit_reviewable(reviewable)

    review_page.select_bundled_action(
      reviewable,
      "post_voting_comment-agree_and_keep_comment",
      bundle_index: 1,
    )
    expect(review_page).to have_reviewable_with_approved_status(reviewable)
  end

  context "when the comment is already deleted" do
    before { comment.trash!(admin) }

    it "allows to agree with the flag and restore the comment" do
      review_page.visit_reviewable(reviewable)
      expect(page).not_to have_text(comment.raw)

      review_page.select_bundled_action(
        reviewable,
        "post_voting_comment-agree_and_restore",
        bundle_index: 1,
      )
      expect(review_page).to have_reviewable_with_approved_status(reviewable)
      expect(page).to have_text(comment.raw)
    end

    it "allows to disagree with the flag and restore the comment" do
      review_page.visit_reviewable(reviewable)

      review_page.select_bundled_action(
        reviewable,
        "post_voting_comment-disagree_and_restore",
        bundle_index: 2,
      )
      expect(review_page).to have_reviewable_with_rejected_status(reviewable)
      expect(page).to have_text(comment.raw)
    end
  end
end
