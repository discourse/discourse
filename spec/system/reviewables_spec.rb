# frozen_string_literal: true

describe "Reviewables", type: :system do
  let(:review_page) { PageObjects::Pages::Review.new }
  fab!(:admin)
  fab!(:theme)
  fab!(:long_post) { Fabricate(:post_with_very_long_raw_content) }
  fab!(:post)
  let(:composer) { PageObjects::Components::Composer.new }

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
    end
  end

  describe "when there is a queued post reviewable with a short post" do
    fab!(:short_queued_reviewable) { Fabricate(:reviewable_queued_post) }

    it "should not show a button to expand/collapse the post content" do
      visit("/review")
      expect(review_page).to have_no_post_body_collapsed
      expect(review_page).to have_no_post_body_toggle
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
    end
  end
end
