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
end
