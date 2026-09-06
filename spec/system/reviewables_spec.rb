# frozen_string_literal: true

describe "Reviewables" do
  let(:review_page) { PageObjects::Pages::Review.new }
  fab!(:admin)
  fab!(:post)
  let(:composer) { PageObjects::Components::Composer.new }
  let(:moderator) { Fabricate(:moderator) }
  let(:toasts) { PageObjects::Components::Toasts.new }
  let(:suspend_user_modal) { PageObjects::Modals::PenalizeUser.new("suspend") }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  describe "when there is a flagged post reviewable with a short post" do
    fab!(:short_reviewable) { Fabricate(:reviewable_flagged_post, target: post) }

    describe "reviewable actions" do
      let(:discard_draft_modal) { PageObjects::Modals::DiscardDraft.new }

      def open_agree_and_edit
        PageObjects::Components::SelectKit.new(".dropdown-select-box.post-agree-and-hide").expand
        find("[data-value='post-agree_and_edit']").click
      end

      it "agree_and_edit does not touch the flag until the edit is saved" do
        visit("/review")

        open_agree_and_edit

        expect(composer).to have_value(post.raw)
        expect(review_page).to have_reviewable_with_pending_status(short_reviewable)

        composer.fill_content("The moderator changed their mind about this.")
        composer.discard

        expect(discard_draft_modal).to be_open

        discard_draft_modal.click_discard

        expect(composer).to be_closed
        expect(review_page).to have_reviewable_with_pending_status(short_reviewable)
        expect(short_reviewable.reload).to be_pending
        expect(post.reload.revisions.count).to eq(0)
      end

      it "agree_and_edit agrees with the flag once the edit is saved" do
        visit("/review")

        open_agree_and_edit

        expect(composer).to have_value(post.raw)

        composer.fill_content("This post has been edited by a moderator.")
        composer.submit

        expect(composer).to be_closed
        expect(toasts).to have_success(I18n.t("reviewables.actions.agree_and_edit.complete"))
        expect(review_page).to have_reviewable_with_approved_status(short_reviewable)
        expect(short_reviewable.reload).to be_approved
        expect(post.reload.raw).to eq("This post has been edited by a moderator.")
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

        select_kit = PageObjects::Components::SelectKit.new(".dropdown-select-box.post-disagree")
        select_kit.expand
        select_kit.select_row_by_value("post-disagree")

        expect(toasts).to have_success(I18n.t("reviewables.actions.disagree.complete"))
      end
    end
  end

  describe "when there are several flagged posts in the queue" do
    fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[3]) }
    fab!(:spammer_one, :user)
    fab!(:spammer_two, :user)

    it "confirms deletion of the author of the reviewable that was acted on" do
      reviewables = {
        spammer_one =>
          PostActionCreator.spam(flagger, Fabricate(:post, user: spammer_one)).reviewable,
        spammer_two =>
          PostActionCreator.spam(flagger, Fabricate(:post, user: spammer_two)).reviewable,
      }

      visit("/review")

      reviewables.each do |spammer, reviewable|
        review_page.delete_user_from_reviewable(
          reviewable,
          "post-delete_user_block",
          confirm: false,
        )

        expect(dialog).to have_content(
          I18n.t("reviewables.actions.reject_user.block.confirm", username: spammer.username),
        )

        dialog.click_no
        expect(dialog).to be_closed
      end
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

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to eq([user_email])
      expect(mail.subject).to match(/You've been rejected on Discourse/)
      expect(mail.body.raw_source).to include rejection_reason
    end
  end

  describe "when there is a suspect user reviewable" do
    fab!(:suspect_user) { Fabricate(:user, approved: false) }
    fab!(:suspect_reviewable) { Fabricate(:suspect_user_reviewable, target: suspect_user) }

    it "allows suspending the user without deleting them" do
      review_page.visit_reviewable(suspect_reviewable)
      review_page.select_bundled_action(suspect_reviewable, "user-suspend_user")

      suspend_user_modal.suspend("spam profile")

      expect(suspend_user_modal).to be_closed
      expect(review_page).to have_reviewable_with_rejected_status(suspect_reviewable)
      expect(review_page).to have_no_scrub_button(suspect_reviewable)
      expect(suspect_user.reload).to be_suspended
      expect(
        UserHistory.find_by(
          action: UserHistory.actions[:suspend_user],
          target_user_id: suspect_user.id,
        ).reviewable_id,
      ).to eq(suspect_reviewable.id)
    end
  end

  context "when performing a review action from the show route" do
    fab!(:contact_group, :group)
    fab!(:contact_user, :user)

    before do
      SiteSetting.site_contact_group_name = contact_group.id.to_s
      SiteSetting.site_contact_username = contact_user.username
    end

    context "with a ReviewableQueuedPost" do
      fab!(:queued_post_reviewable, :reviewable_queued_post)

      it "delete_user does not delete reviewable" do
        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present
        expect(review_page).to have_reviewable_with_pending_status(queued_post_reviewable)

        review_page.select_bundled_action(queued_post_reviewable, "delete_user")

        expect(dialog).to have_content(
          "Are you sure you want to delete @#{queued_post_reviewable.target_created_by.username}?",
        )
        expect(page).to have_css(".dialog-footer .btn-danger", text: I18n.t("js.delete"))
        dialog.click_danger

        expect(review_page).to have_no_error_dialog_visible
        expect(review_page).to have_reviewable_with_rejected_status(queued_post_reviewable)
        expect(review_page).to have_no_reviewable_action_dropdown
        expect(queued_post_reviewable.reload).to be_rejected
        expect(queued_post_reviewable.target_created_by).to be_nil
      end

      it "delete_user can be cancelled from the confirmation dialog" do
        review_page.visit_reviewable(queued_post_reviewable)
        review_page.select_bundled_action(queued_post_reviewable, "delete_user")

        dialog.click_no

        expect(dialog).to be_closed
        expect(review_page).to have_reviewable_with_pending_status(queued_post_reviewable)
        expect(queued_post_reviewable.reload).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present

        try_until_success do
          expect(
            ReviewableClaimedTopic.where(topic_id: queued_post_reviewable.topic_id),
          ).to be_empty
        end
      end

      it "reject_and_suspend rejects the post and suspends its author" do
        review_page.visit_reviewable(queued_post_reviewable)
        review_page.select_bundled_action(queued_post_reviewable, "reject_and_suspend")

        suspend_user_modal.suspend("spam")

        expect(suspend_user_modal).to be_closed
        expect(review_page).to have_reviewable_with_rejected_status(queued_post_reviewable)
        expect(queued_post_reviewable.reload).to be_rejected
        expect(queued_post_reviewable.target_created_by.reload).to be_suspended
      end

      it "allows revising and rejecting to send a PM to the user" do
        revise_modal = PageObjects::Modals::Base.new

        review_page.visit_reviewable(queued_post_reviewable)

        expect(queued_post_reviewable).to be_pending
        expect(queued_post_reviewable.target_created_by).to be_present

        review_page.select_bundled_action(queued_post_reviewable, "revise_and_reject_post")

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

        review_page.select_bundled_action(queued_post_reviewable, "revise_and_reject_post")
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
    fab!(:reviewable) { Fabricate(:reviewable_flagged_post, target: post) }
    fab!(:reviewable2, :reviewable)

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

  describe "custom community moderator guide topic" do
    fab!(:group)
    fab!(:topic) { Fabricate(:topic, title: "Moderator guide") }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:reviewable, :reviewable_queued_post)

    before { group.add(admin) }

    it "displays the custom guide topic link when configured" do
      SiteSetting.moderator_guide_topic = topic.id

      review_page.visit_reviewable(reviewable)
      expect(review_page).to have_css(
        "a.review-resources__link",
        text: I18n.t("js.review.help.community_moderation_guide"),
      )
    end

    it "does not display anything when no custom guide topic configured" do
      SiteSetting.moderator_guide_topic = ""

      review_page.visit_reviewable(reviewable)
      expect(review_page).to have_no_css(
        "a.review-resources__link",
        text: I18n.t("js.review.help.community_moderation_guide"),
      )
    end
  end

  describe "XSS prevention in queued post titles via server-side cooking" do
    fab!(:untrusted_user) { Fabricate(:user, trust_level: 0) }

    it "escapes markup in queued post titles instead of rendering it" do
      ReviewableQueuedPost.needs_review!(
        target_created_by: untrusted_user,
        created_by: untrusted_user,
        payload: {
          raw: "This is the post body",
          title: "<img src=x onerror=\"alert('XSS')\"><script>alert(1)</script> & <b>Bold</b>",
        },
      )

      visit("/review")

      title_html = page.find(".title-text", match: :first).native.inner_html

      expect(title_html).to include("&lt;img")
      expect(title_html).to include("&lt;script&gt;")
      expect(title_html).to include("&lt;b&gt;")
      expect(title_html).to include("&amp;")
      expect(page).to have_no_css(
        ".title-text img, .title-text script, .title-text b",
        visible: :all,
      )
    end
  end

  describe "when deleting and blocking a spammer from a hidden flagged post" do
    let(:acted_reviewable) do
      flag = PostActionCreator.spam(flagger, Fabricate(:post, user: spammer)).reviewable
      flag.target.update!(
        hidden: true,
        hidden_at: Time.zone.now,
        hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
      )
      flag
    end

    include_examples "resolving a spammer's reviewables on user deletion"
  end

  describe "when deleting a spammer from a queued post" do
    let(:acted_reviewable) do
      Fabricate(
        :reviewable_queued_post,
        created_by: Discourse.system_user,
        target_created_by: spammer,
      )
    end

    include_examples "resolving a spammer's reviewables on user deletion"
  end
end
