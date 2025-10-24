# frozen_string_literal: true

describe "Viewing reviewable item", type: :system do
  fab!(:admin)
  fab!(:group)
  fab!(:reviewable_flagged_post)

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:refreshed_review_page) { PageObjects::Pages::RefreshedReview.new }
  let(:review_note_form) { PageObjects::Components::ReviewNoteForm.new }

  describe "when user is part of the groups list of the `reviewable_ui_refresh` site setting" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      group.add(admin)
      sign_in(admin)
    end

    describe "when the reviewable item is a flagged post" do
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
        expect(flag_reason_component).to have_off_topic_flag_reason(
          reviewable_flagged_post,
          count: 1,
        )
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

      it "shows the topic status, title link, category badge and tags of the topic associated with the reviewable item correctly" do
        post = reviewable_flagged_post.post
        topic = reviewable_flagged_post.topic
        category = Fabricate(:category)
        topic.change_category_to_id(category.id)
        tag_1 = Fabricate(:tag)
        tag_2 = Fabricate(:tag)
        topic.tags = [tag_1, tag_2]
        topic.closed = true
        topic.save!

        topic_link_component =
          review_page.visit_reviewable(reviewable_flagged_post).topic_link_component

        expect(topic_link_component).to have_closed_topic_status

        expect(topic_link_component).to have_topic_link(
          topic_title: topic.title,
          post_url: post.full_url,
        )

        expect(topic_link_component).to have_category_badge(category.name)
        expect(topic_link_component).to have_tag_link(tag_name: tag_1.name, tag_url: tag_1.url)
        expect(topic_link_component).to have_tag_link(tag_name: tag_2.name, tag_url: tag_2.url)

        # TODO: Add test for watched words highlighting
      end

      it "allows to add notes and persists them when toggle tabs" do
        refreshed_review_page.visit_reviewable(reviewable_flagged_post)
        refreshed_review_page.click_timeline_tab
        review_note_form.add_note("This is a review note.")
        refreshed_review_page.click_insights_tab
        refreshed_review_page.click_timeline_tab
        expect(page).to have_text("This is a review note.")
      end
    end

    describe "when the reviewable item is a user" do
      fab!(:user)
      let(:rejection_reason_modal) { PageObjects::Modals::RejectReasonReviewable.new }
      let(:scrub_user_modal) { PageObjects::Modals::ScrubRejectedUser.new }

      before do
        SiteSetting.must_approve_users = true
        Jobs.run_immediately!
        user.update!(approved: false)
        user.activate
      end

      it "shows the user's name and admin profile link" do
        reviewable = ReviewableUser.find_by_target_id(user.id)

        refreshed_review_page.visit_reviewable(reviewable)
        expect(page).to have_text(user.name)
        expect(page).to have_link(user.username, href: "/admin/users/#{user.id}/#{user.username}")
      end

      it "Allow to delete user" do
        reviewable = ReviewableUser.find_by_target_id(user.id)
        user_email = user.email

        refreshed_review_page.visit_reviewable(reviewable)
        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user")
        expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)

        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to eq([user_email])
        expect(mail.subject).to match(/You've been rejected on Discourse/)
      end

      it "Allows scrubbing user data after rejection" do
        scrubbing_reason = "a spammer who knows how to make GDPR requests"
        reviewable = ReviewableUser.find_by_target_id(user.id)
        user_email = user.email

        refreshed_review_page.visit_reviewable(reviewable)
        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user")

        expect(refreshed_review_page).to have_scrub_button(reviewable)
        refreshed_review_page.click_scrub_button(reviewable)

        expect(scrub_user_modal.scrub_button).to be_disabled
        scrub_user_modal.fill_in_scrub_reason(scrubbing_reason)
        expect(scrub_user_modal.scrub_button).not_to be_disabled
        scrub_user_modal.scrub_button.click

        expect(refreshed_review_page).to have_reviewable_with_scrubbed_by(
          reviewable,
          admin.username,
        )
        expect(refreshed_review_page).to have_reviewable_with_scrubbed_reason(
          reviewable,
          scrubbing_reason,
        )
        expect(refreshed_review_page).to have_reviewable_with_scrubbed_at(
          reviewable,
          reviewable.payload["scrubbed_at"],
        )
        expect(refreshed_review_page).to have_no_scrub_button(reviewable)
      end

      it "Allows to delete and block user" do
        reviewable = ReviewableUser.find_by_target_id(user.id)
        user_email = user.email

        refreshed_review_page.visit_reviewable(reviewable)
        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user_block")
        expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)
      end
    end
  end
end
