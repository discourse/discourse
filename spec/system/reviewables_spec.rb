# frozen_string_literal: true

describe "Reviewables", type: :system do
  let(:review_page) { PageObjects::Pages::Review.new }
  fab!(:admin)
  fab!(:theme)
  fab!(:long_post) { Fabricate(:post_with_very_long_raw_content) }
  fab!(:post)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:moderator) { Fabricate(:moderator) }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { sign_in(admin) }

  describe "when there is a flagged post reviewable with a long post" do
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

  describe "when there is a flagged post reviewable with a short post" do
    fab!(:short_reviewable) { Fabricate(:reviewable_flagged_post, target: post) }

    it "should not show a button to expand/collapse the post content" do
      visit("/review")
      expect(review_page).to have_no_post_body_collapsed
      expect(review_page).to have_no_post_body_toggle
    end

    describe "reviewable actions" do
      it "should have agree_and_edit action" do
        visit("/review")
        select_kit =
          PageObjects::Components::SelectKit.new(".dropdown-select-box.post-agree-and-hide")
        select_kit.expand

        expect(select_kit).to have_option_value("post-agree_and_edit")
      end

      it "agree_and_edit should open the composer" do
        visit("/review")
        select_kit =
          PageObjects::Components::SelectKit.new(".dropdown-select-box.post-agree-and-hide")
        select_kit.expand

        find("[data-value='post-agree_and_edit']").click

        expect(composer).to be_opened
        expect(composer.composer_input.value).to eq(post.raw)
        expect(toasts).to have_success(I18n.t("reviewables.actions.agree_and_edit.complete"))
      end

      it "should open a modal when suspending a user" do
        visit("/review")

        select_kit =
          PageObjects::Components::SelectKit.new(".dropdown-select-box.post-agree-and-hide")
        select_kit.expand

        select_kit.select_row_by_value("post-agree_and_suspend")

        expect(review_page).to have_css(
          "#discourse-modal-title",
          text: I18n.t("js.flagging.take_action_options.suspend.title"),
        )
      end

      it "should show a toast when disagreeing with a flag flag" do
        visit("/review")

        find(".post-disagree").click

        expect(toasts).to have_success(I18n.t("reviewables.actions.disagree.complete"))
      end
    end
  end

  describe "when there is a queued post reviewable with a short post" do
    fab!(:short_queued_reviewable) { Fabricate(:reviewable_queued_post) }

    it "should not show a button to expand/collapse the post content" do
      visit("/review")
      expect(review_page).to have_no_post_body_collapsed
      expect(review_page).to have_no_post_body_toggle
    end

    it "should apply correct button classes to actions" do
      visit("/review")

      expect(page).to have_css(".approve-post.btn-success")
      expect(page).to have_css(".reject-post .btn-danger")

      expect(page).to have_no_css(".approve-post.btn-default")
      expect(page).to have_no_css(".reject-post .btn-default")
    end
  end

  describe "when there is a queued post reviewable with a long post" do
    fab!(:long_queued_reviewable) { Fabricate(:reviewable_queued_long_post) }

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

  describe "when there is a reviewable user" do
    fab!(:user)
    let(:rejection_reason_modal) { PageObjects::Modals::RejectReasonReviewable.new }
    let(:scrub_user_modal) { PageObjects::Modals::ScrubRejectedUser.new }

    before do
      SiteSetting.must_approve_users = true
      Jobs.run_immediately!
      user.update!(approved: false)
      user.activate
    end

    it "Rejecting user sends rejection email and updates reviewable with rejection reason" do
      rejection_reason = "user is spamming"
      reviewable = ReviewableUser.find_by_target_id(user.id)
      # cache it for later assertion instead of querying UserHistory
      user_email = user.email

      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "user-delete_user")
      rejection_reason_modal.fill_in_rejection_reason(rejection_reason)
      rejection_reason_modal.select_send_rejection_email_checkbox
      rejection_reason_modal.delete_user

      expect(review_page).to have_reviewable_with_rejected_status(reviewable)
      expect(review_page).to have_reviewable_with_rejection_reason(reviewable, rejection_reason)

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to match(/You've been rejected on Discourse/)
      expect(mail.body.raw_source).to include rejection_reason
    end

    it "Allows scrubbing user data after rejection" do
      rejection_reason = "user is spamming"
      scrubbing_reason = "a spammer who knows how to make GDPR requests"
      reviewable = ReviewableUser.find_by_target_id(user.id)

      review_page.visit_reviewable(reviewable)
      review_page.select_bundled_action(reviewable, "user-delete_user")
      rejection_reason_modal.fill_in_rejection_reason(rejection_reason)
      rejection_reason_modal.delete_user

      expect(review_page).to have_reviewable_with_rejected_status(reviewable)
      expect(review_page).to have_reviewable_with_rejection_reason(reviewable, rejection_reason)

      expect(review_page).to have_scrub_button(reviewable)
      review_page.click_scrub_button(reviewable)

      expect(scrub_user_modal.scrub_button).to be_disabled
      scrub_user_modal.fill_in_scrub_reason(scrubbing_reason)
      expect(scrub_user_modal.scrub_button).not_to be_disabled
      scrub_user_modal.scrub_button.click

      expect(review_page).to have_reviewable_with_scrubbed_by(reviewable, admin.username)
      expect(review_page).to have_reviewable_with_scrubbed_reason(reviewable, scrubbing_reason)
      expect(review_page).to have_reviewable_with_scrubbed_at(
        reviewable,
        reviewable.payload["scrubbed_at"],
      )
      expect(review_page).to have_no_scrub_button(reviewable)
    end
  end

  context "when performing a review action from the show route" do
    fab!(:contact_group) { Fabricate(:group) }
    fab!(:contact_user) { Fabricate(:user) }

    before do
      SiteSetting.site_contact_group_name = contact_group.name
      SiteSetting.site_contact_username = contact_user.username
    end

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

      it "allows revising and rejecting to send a PM to the user" do
        revise_modal = PageObjects::Modals::Base.new

        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present

        review_page.select_action(queued_post_reviewable, "revise_and_reject_post")

        expect(revise_modal).to be_open

        reason_dropdown =
          PageObjects::Components::SelectKit.new(".revise-and-reject-reviewable__reason")
        reason_dropdown.select_row_by_value(SiteSetting.reviewable_revision_reasons_map.first)
        find(".revise-and-reject-reviewable__feedback").fill_in(with: "This is a test")
        revise_modal.click_primary_button

        expect(review_page).to have_reviewable_with_rejected_status(queued_post_reviewable)
        expect(queued_post_reviewable.reload).to be_rejected

        topic = Topic.where(archetype: Archetype.private_message).last
        expect(topic.topic_allowed_users.pluck(:user_id)).to include(contact_user.id)
        expect(topic.topic_allowed_groups.pluck(:group_id)).to include(contact_group.id)
        expect(topic.title).to eq(
          I18n.t(
            "system_messages.reviewable_queued_post_revise_and_reject.subject_template",
            topic_title: queued_post_reviewable.topic.title,
          ),
        )
      end

      it "claims the reviewable while revising, and unclaims it when cancelling" do
        revise_modal = PageObjects::Modals::Base.new

        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present

        review_page.select_action(queued_post_reviewable, "revise_and_reject_post")

        expect(revise_modal).to be_open

        expect(page).to have_css(".claimed-actions")

        revise_modal.close

        expect(revise_modal).to be_closed
        expect(page).to have_no_css(".claimed-actions")
      end

      it "allows selecting a custom reason for revise and reject" do
        revise_modal = PageObjects::Modals::Base.new

        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present

        review_page.select_action(queued_post_reviewable, "revise_and_reject_post")
        expect(revise_modal).to be_open

        reason_dropdown =
          PageObjects::Components::SelectKit.new(".revise-and-reject-reviewable__reason")
        reason_dropdown.select_row_by_value("other_reason")
        find(".revise-and-reject-reviewable__custom-reason").fill_in(with: "I felt like it")
        find(".revise-and-reject-reviewable__feedback").fill_in(with: "This is a test")
        revise_modal.click_primary_button

        expect(review_page).to have_reviewable_with_rejected_status(queued_post_reviewable)
      end

      context "with reviewable claiming enabled" do
        before { SiteSetting.reviewable_claiming = "required" }

        it "properly claims and unclaims the reviewable" do
          review_page.visit_reviewable(queued_post_reviewable)

          expect(review_page).to have_no_reviewable_action_dropdown

          review_page.click_claim_reviewable

          expect(review_page).to have_reviewable_action_dropdown

          review_page.click_unclaim_reviewable

          expect(review_page).to have_no_reviewable_action_dropdown
        end
      end
    end
  end

  describe "when there is an unknown plugin reviewable" do
    fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: long_post) }
    fab!(:reviewable2) { Fabricate(:reviewable) }

    before do
      reviewable.update_columns(type: "UnknownPlugin", type_source: "some-plugin")
      reviewable2.update_columns(type: "UnknownSource", type_source: "unknown")
    end

    it "informs admin and allows to delete them" do
      visit("/review")
      expect(review_page).to have_information_about_unknown_reviewables_visible
      expect(review_page).to have_listing_for_unknown_reviewables_plugin(
        reviewable.type,
        reviewable.type_source,
      )
      expect(review_page).to have_listing_for_unknown_reviewables_unknown_source(reviewable2.type)
      review_page.click_ignore_all_unknown_reviewables
      expect(review_page).to have_no_information_about_unknown_reviewables_visible
    end

    it "does not inform moderator about them" do
      sign_in(moderator)

      visit("/review")
      expect(review_page).to have_no_information_about_unknown_reviewables_visible
    end
  end
end
