# frozen_string_literal: true

describe "Viewing reviewable item", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:reviewable_flagged_post)

  let(:review_page) { PageObjects::Pages::Review.new }

  describe "when user is part of the groups list of the `reviewable_ui_refresh` site setting" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      group.add(admin)
      sign_in(admin)
    end

    it "shows the new reviewable UI" do
      review_page.visit_reviewable(reviewable_flagged_post)

      expect(page).to have_selector(".review-container")
    end

    it "shows the reviewable item with badges stating the flag reason and count" do
      _spam_reviewable_score =
        Fabricate(
          :reviewable_score,
          reviewable: reviewable_flagged_post,
          reviewable_score_type: ReviewableScore.types[:spam],
        )

      _off_topic_reviewable_score =
        Fabricate(
          :reviewable_score,
          reviewable: reviewable_flagged_post,
          reviewable_score_type: ReviewableScore.types[:off_topic],
        )

      _illegal_reviewable_score =
        Fabricate(
          :reviewable_score,
          reviewable: reviewable_flagged_post,
          reviewable_score_type: ReviewableScore.types[:illegal],
        )

      _inappropriate_reviewable_score =
        Fabricate(
          :reviewable_score,
          reviewable: reviewable_flagged_post,
          reviewable_score_type: ReviewableScore.types[:inappropriate],
        )

      _needs_approval_reviewable_score =
        Fabricate(
          :reviewable_score,
          reviewable: reviewable_flagged_post,
          reviewable_score_type: ReviewableScore.types[:needs_approval],
        )

      flag_reason_component =
        review_page.visit_reviewable(reviewable_flagged_post).flag_reason_component

      expect(flag_reason_component).to have_spam_flag_reason(reviewable_flagged_post, count: 1)
      expect(flag_reason_component).to have_off_topic_flag_reason(reviewable_flagged_post, count: 1)
      expect(flag_reason_component).to have_illegal_flag_reason(reviewable_flagged_post, count: 1)

      expect(flag_reason_component).to have_inappropriate_flag_reason(
        reviewable_flagged_post,
        count: 2,
      )

      expect(flag_reason_component).to have_needs_approval_flag_reason(
        reviewable_flagged_post,
        count: 1,
      )
    end
  end
end
