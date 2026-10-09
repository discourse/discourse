# frozen_string_literal: true

RSpec.describe "Complete a reviewable penalty" do
  fab!(:admin)
  fab!(:post)
  fab!(:reviewable) do
    Fabricate(:reviewable_flagged_post, target: post, target_created_by: post.user)
  end

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:admin_user_page) { PageObjects::Pages::AdminUser.new }

  before { sign_in(admin) }

  %w[suspend silence].each do |penalty|
    it "lets a moderator cancel, correct and complete a #{penalty} action" do
      modal = PageObjects::Modals::PenalizeUser.new(penalty)
      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "post-agree_and_#{penalty}", bundle_index: 1)
      modal.cancel

      expect(modal).to be_closed
      admin_user_page.visit(post.user)
      expect(admin_user_page).to public_send("have_#{penalty}_button")
      review_page.visit_reviewable(reviewable)
      expect(review_page).to have_reviewable_with_pending_status(reviewable)

      review_page.select_bundled_action(reviewable, "post-agree_and_#{penalty}", bundle_index: 1)
      modal.public_send("fill_in_#{penalty}_reason", "x" * 301)
      modal.set_future_date("tomorrow")
      modal.perform

      expect(modal).to have_validation_error
      expect(review_page).to have_reviewable_with_pending_status(reviewable)

      modal.public_send("fill_in_#{penalty}_reason", "Repeated spam")
      modal.perform

      expect(modal).to be_closed
      review_page.visit_reviewable(reviewable)
      expect(review_page).to have_reviewable_with_approved_status(reviewable)
      admin_user_page.visit(post.user)
      expect(admin_user_page).to public_send("have_no_#{penalty}_button")
    end
  end
end
