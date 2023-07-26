# frozen_string_literal: true

describe "Reviewables", type: :system do
  let(:review_page) { PageObjects::Pages::Review.new }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:theme) { Fabricate(:theme) }
  fab!(:long_post) { Fabricate(:post_with_very_long_raw_content) }

  before { sign_in(admin) }

  describe "when there is a reviewable with a long post" do
    fab!(:long_reviewable) { Fabricate(:reviewable_flagged_post, target: long_post) }

    it "should show a button to expand/collapse the post content" do
      visit("/review")
      expect(review_page).to have_post_body_collapsed
      expect(review_page).to have_post_body_toggle
      review_page.click_post_body_toggle
      expect(review_page).to have_no_post_body_collapsed
      review_page.click_post_body_toggle
      expect(review_page).to have_post_body_collapsed
    end
  end

  describe "when there is a reviewable with a short post" do
    fab!(:short_reviewable) { Fabricate(:reviewable_flagged_post) }

    it "should not show a button to expand/collapse the post content" do
      visit("/review")
      expect(review_page).to have_no_post_body_collapsed
      expect(review_page).to have_no_post_body_toggle
    end
  end

  context "when performing a review action from the show route" do
    context "with a ReviewableQueuedPost" do
      fab!(:queued_post_reviewable) { Fabricate(:reviewable_queued_post) }

      it "delete_user does not delete reviewable" do
        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present
        expect(review_page).to have_reviewable_action_dropdown
        expect(review_page).to have_reviewable_with_pending_status(queued_post_reviewable)

        review_page.select_bundled_action(queued_post_reviewable, "delete_user")

        expect(review_page).to have_no_error_dialog_visible
        expect(review_page).to have_reviewable_with_rejected_status(queued_post_reviewable)
        expect(review_page).to have_no_reviewable_action_dropdown
        expect(queued_post_reviewable.reload).to be_rejected
        expect(queued_post_reviewable.target_created_by).to be_nil
      end
    end
  end
end
