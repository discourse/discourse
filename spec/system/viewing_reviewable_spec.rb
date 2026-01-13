# frozen_string_literal: true

require "discourse_ip_info"

describe "Viewing reviewable item", type: :system do
  fab!(:admin)
  fab!(:moderator)
  fab!(:group)
  fab!(:reviewable_flagged_post) do
    Fabricate(
      :reviewable_flagged_post,
      target_created_by: Fabricate(:user, email: "flagged@example.com"),
    )
  end

  let(:review_page) { PageObjects::Pages::Review.new }
  let(:refreshed_review_page) { PageObjects::Pages::RefreshedReview.new }
  let(:review_note_form) { PageObjects::Components::ReviewNoteForm.new }

  describe "when user is part of the groups list of the `reviewable_ui_refresh` site setting" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      SiteSetting.reviewable_old_moderator_actions = false
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

      it "shows confirmation dialog when navigating away with unsaved note, but not after clearing the note" do
        dialog = PageObjects::Components::Dialog.new

        refreshed_review_page.visit_reviewable(reviewable_flagged_post)
        refreshed_review_page.click_timeline_tab

        review_note_form.form.fill_in("content", with: "This is a draft note")

        click_logo

        expect(dialog).to be_open
        expect(dialog).to have_content(I18n.t("js.form_kit.dirty_form"))

        dialog.click_no

        expect(page).to have_current_path("/review/#{reviewable_flagged_post.id}")

        review_note_form.form.fill_in("content", with: "")

        click_logo

        expect(dialog).to be_closed
        expect(page).to have_current_path("/")
      end

      it "displays the flagged user's email address in user activity" do
        refreshed_review_page.visit_reviewable(reviewable_flagged_post)
        refreshed_review_page.click_insights_tab

        expect(page).to have_text("flagged@example.com")
      end

      describe "Moderation history" do
        fab!(:flagged_user) { reviewable_flagged_post.target_created_by }

        it "displays the number of times the user has been silenced, suspended and number of rejected posts" do
          UserHistory.create!(
            action: UserHistory.actions[:silence_user],
            target_user_id: flagged_user.id,
            acting_user_id: admin.id,
          )
          UserHistory.create!(
            action: UserHistory.actions[:silence_user],
            target_user_id: flagged_user.id,
            acting_user_id: admin.id,
          )
          UserHistory.create!(
            action: UserHistory.actions[:suspend_user],
            target_user_id: flagged_user.id,
            acting_user_id: admin.id,
          )
          ReviewableQueuedPost.create!(
            created_by: admin,
            target_created_by: flagged_user,
            status: Reviewable.statuses[:rejected],
            payload: {
              raw: "test post 1",
            },
          )
          ReviewableQueuedPost.create!(
            created_by: admin,
            target_created_by: flagged_user,
            status: Reviewable.statuses[:rejected],
            payload: {
              raw: "test post 2",
            },
          )

          refreshed_review_page.visit_reviewable(reviewable_flagged_post)
          refreshed_review_page.click_insights_tab

          expect(page).to have_text(
            I18n.t("js.review.insights.moderation_history.silenced", count: 2),
          )
          expect(page).to have_text(
            I18n.t("js.review.insights.moderation_history.suspended", count: 1),
          )
          expect(page).to have_text(
            I18n.t("js.review.insights.moderation_history.rejected_posts", count: 2),
          )
        end
      end

      describe "IP lookup" do
        fab!(:reviewable_flagged_post)

        before do
          reviewable_flagged_post.target_created_by.update!(ip_address: "81.2.69.142")

          DiscourseIpInfo.open_db(File.join(Rails.root, "spec", "fixtures", "mmdb"))
          Resolv::DNS
            .any_instance
            .stubs(:getname)
            .with("81.2.69.142")
            .returns("ip-81-2-69-142.example.com")
        end

        it "shows IP lookup information when insights tab is viewed" do
          refreshed_review_page.visit_reviewable(reviewable_flagged_post)
          refreshed_review_page.click_insights_tab

          expect(refreshed_review_page).to have_ip_lookup_info
        end

        it "displays IP location, hostname, and organization when available" do
          refreshed_review_page.visit_reviewable(reviewable_flagged_post)
          refreshed_review_page.click_insights_tab

          expect(refreshed_review_page).to have_ip_location("London, England, United Kingdom")
          expect(refreshed_review_page).to have_ip_hostname("ip-81-2-69-142.example.com")
        end

        it "shows other accounts link when there are multiple accounts with same IP" do
          other_user_1 = Fabricate(:user, ip_address: "81.2.69.142")
          other_user_2 = Fabricate(:user, ip_address: "81.2.69.142")

          refreshed_review_page.visit_reviewable(reviewable_flagged_post)
          refreshed_review_page.click_insights_tab

          expect(refreshed_review_page).to have_other_accounts_link(count: 2)
        end

        it "opens modal with account list when clicking other accounts link" do
          other_user = Fabricate(:user, username: "suspicious_user", ip_address: "81.2.69.142")

          refreshed_review_page.visit_reviewable(reviewable_flagged_post)
          refreshed_review_page.click_insights_tab
          refreshed_review_page.click_other_accounts_link

          expect(refreshed_review_page).to have_ip_lookup_modal
          expect(refreshed_review_page).to have_account_in_modal(other_user.username)
        end

        context "when category moderator" do
          fab!(:category)
          fab!(:trust_level_1_user, :trust_level_1)
          fab!(:category_moderation_group) do
            Fabricate(
              :category_moderation_group,
              category: category,
              group: trust_level_1_user.groups.last,
            )
          end

          before do
            SiteSetting.enable_category_group_moderation = true
            reviewable_flagged_post.topic.change_category_to_id(category.id)
            sign_in trust_level_1_user
          end

          it "does not show IP information" do
            visit "/"
            refreshed_review_page.visit_reviewable(reviewable_flagged_post)
            refreshed_review_page.click_insights_tab

            expect(page).not_to have_text("The requested URL or resource could not be found.")
          end
        end
      end
    end

    describe "when the reviewable item is a queued post" do
      fab!(:reviewable_queued_post)

      it "allows to edit post when old moderator actions are enabled" do
        SiteSetting.reviewable_old_moderator_actions = true
        refreshed_review_page.visit_reviewable(reviewable_queued_post)

        expect(page).to have_text("hello world post contents.")
        refreshed_review_page.click_edit_post_button
        refreshed_review_page.fill_post_content("Hello world from system spec!")
        refreshed_review_page.save_post_edit

        expect(page).to have_text("Hello world from system spec!")
        expect(page).not_to have_text("hello world post contents.")
      end

      it "shows context question for rejected queued post" do
        reviewable_queued_post.update!(status: Reviewable.statuses[:rejected])

        refreshed_review_page.visit_reviewable(reviewable_queued_post)

        expect(refreshed_review_page).to have_reviewable_with_rejected_status(
          reviewable_queued_post,
        )
        expect(refreshed_review_page).to have_context_question(
          reviewable_queued_post,
          I18n.t("js.review.context_question.approve_post"),
        )
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

      it "Allow to delete and scrub user" do
        reviewable = ReviewableUser.find_by_target_id(user.id)

        refreshed_review_page.visit_reviewable(reviewable)

        expect(page).to have_text(user.name)
        expect(page).to have_link(user.username, href: "/admin/users/#{user.id}/#{user.username}")

        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user")
        expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)

        expect(page).to have_text(user.name)

        refreshed_review_page.select_bundled_action(reviewable, "user-scrub")

        scrubbing_reason = "a spammer who knows how to make GDPR requests"
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
        expect(page).not_to have_text(user.name)
      end

      it "Allows to delete and block user" do
        reviewable = ReviewableUser.find_by_target_id(user.id)

        refreshed_review_page.visit_reviewable(reviewable)
        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user_block")
        expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)
        expect(refreshed_review_page).to have_rejected_item_in_timeline(reviewable)
      end

      it "Allows to approve user" do
        reviewable = ReviewableUser.find_by_target_id(user.id)

        refreshed_review_page.visit_reviewable(reviewable)
        refreshed_review_page.select_bundled_action(
          reviewable,
          "user-approve_user",
          "user-approve_user",
        )

        expect(refreshed_review_page).to have_reviewable_with_approved_status(reviewable)
        expect(refreshed_review_page).to have_approved_item_in_timeline(reviewable)
      end

      it "Allow to delete and scrub user when old moderator actions are enabled" do
        SiteSetting.reviewable_old_moderator_actions = true

        reviewable = ReviewableUser.find_by_target_id(user.id)

        refreshed_review_page.visit_reviewable(reviewable)

        expect(page).to have_text(user.name)
        expect(page).to have_link(user.username, href: "/admin/users/#{user.id}/#{user.username}")

        refreshed_review_page.select_bundled_action(reviewable, "user-delete_user")
        rejection_reason_modal.fill_in_rejection_reason("Spamming the site")
        rejection_reason_modal.delete_user

        expect(refreshed_review_page).to have_reviewable_with_rejected_status(reviewable)

        expect(page).to have_text(user.name)

        refreshed_review_page.click_scrub_user_button

        scrubbing_reason = "a spammer who knows how to make GDPR requests"
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
        expect(page).not_to have_text(user.name)
      end
    end
  end

  describe "moderator" do
    before do
      SiteSetting.reviewable_ui_refresh = group.name
      SiteSetting.reviewable_old_moderator_actions = false
      group.add(admin)
      group.add(moderator)
      sign_in(moderator)
    end

    it "shows claimed and unclaimed events in the timeline" do
      SiteSetting.reviewable_claiming = "required"

      refreshed_review_page.visit_reviewable(reviewable_flagged_post)
      expect(refreshed_review_page).to have_history_items(count: 2)
      expect(refreshed_review_page).to have_created_at_history_item

      refreshed_review_page.click_claim_reviewable
      page.refresh
      expect(refreshed_review_page).to have_history_items(count: 3)
      expect(refreshed_review_page).to have_claimed_history_item(moderator)

      refreshed_review_page.click_unclaim_reviewable
      page.refresh
      expect(refreshed_review_page).to have_history_items(count: 4)
      expect(refreshed_review_page).to have_unclaimed_history_item(moderator)

      # remove history items created by deleted users
      UserDestroyer.new(admin).destroy(moderator)
      sign_in(admin)
      refreshed_review_page.visit_reviewable(reviewable_flagged_post)

      expect(refreshed_review_page).to have_history_items(count: 2)
    end
  end
end
