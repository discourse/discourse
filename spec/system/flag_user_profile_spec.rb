# frozen_string_literal: true

RSpec.describe "Flagging a user profile" do
  fab!(:reporter) { Fabricate(:trust_level_2, refresh_auto_groups: true) }
  fab!(:target, :user)
  fab!(:moderator)

  let(:flag_modal) { PageObjects::Modals::Flag.new }
  let(:review_page) { PageObjects::Pages::Review.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before { SiteSetting.flaggable_user_profiles = true }

  context "when visiting a public profile while signed out" do
    before { SiteSetting.hide_new_user_profiles = false }

    it "offers an email link with the profile URL when anonymous illegal-content reporting is enabled" do
      SiteSetting.contact_email = "contact@example.com"
      visit(target.relative_url)
      expect(page).to have_no_button(I18n.t("js.flagging_profile.action"))

      SiteSetting.allow_all_users_to_flag_illegal_content = true
      page.refresh
      click_button(I18n.t("js.flagging_profile.action"))
      modal = PageObjects::Modals::AnonymousFlag.new
      expect(modal.body).to have_link(SiteSetting.contact_email)

      SiteSetting.email_address_to_report_illegal_content = "reports@example.com"
      visit("#{target.relative_url}/summary")
      click_button(I18n.t("js.flagging_profile.action"))
      link = modal.body.find_link(SiteSetting.email_address_to_report_illegal_content)
      recipient, query = link[:href].split("?", 2)
      expect(recipient).to eq("mailto:reports@example.com")
      expect(URI.decode_www_form(query).to_h.fetch("body")).to eq(
        URI.join(page.current_url, target.relative_url).to_s,
      )
    end

    it "lets a visitor verify their email and submit a DSA notice directly from the profile" do
      enable_dsa_reporting
      SiteSetting.disable_emails = "no"
      Jobs.run_immediately!
      visit("#{target.relative_url}/summary")
      click_button(I18n.t("js.flagging_profile.action"))

      notice_modal = PageObjects::Modals::DsaNotice.new
      expect(notice_modal).to be_open
      expect(notice_modal.body).to have_field(
        I18n.t("js.dsa_notice.content_url"),
        with: URI.join(page.current_url, target.relative_url).to_s,
        disabled: true,
      )
      notice_modal.enter_email("visitor@example.com")
      notice_modal.request_email_code
      expect(notice_modal).to have_verification_code_input
      code = ActionMailer::Base.deliveries.last.text_part.decoded[/\b[0-9]{6}\b/]
      notice_modal.fill_verification_code(code)
      expect(notice_modal).to have_verified_email
      notice_modal.enter_report(
        name: "Alex Morgan",
        explanation:
          "This profile advertises counterfeit goods as authentic and directs buyers to send payment.",
      )
      notice_modal.accept_declaration
      notice_modal.submit_report
      expect(notice_modal).to have_confirmation
    end
  end

  it "lets a member flag illegal content and a moderator review the reported profile fields" do
    SiteSetting.review_queue_consistent_answers = true
    bio = "Follow this link for a prize"
    card_background = Fabricate(:upload)
    target.user_profile.update!(bio_raw: bio, card_background_upload: card_background)
    field = Fabricate(:user_field, name: "Organization", show_on_profile: true)
    target.set_user_field(field.id, "Example organization")
    target.save_custom_fields

    sign_in(reporter)
    PageObjects::Pages::User.new.visit(target)
    click_button(I18n.t("js.flagging_profile.action"))
    flag_modal.choose_type(:illegal)
    flag_modal.fill_message("The offer advertised in this profile appears to be illegal.")
    expect(flag_modal).to have_css(".flag-modal__create-flag:disabled")
    flag_modal.check_confirmation
    flag_modal.confirm_flag
    expect(toasts).to have_success(I18n.t("js.flagging_profile.submitted"))

    target.user_profile.update!(bio_raw: "Updated bio", card_background_upload: nil)
    sign_in(moderator)
    reviewable = ReviewableFlaggedProfile.sole
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_context_question(reviewable, "Is this profile illegal?")
    within(".reviewable-user-fields") do
      expect(page).to have_link(target.username, href: target.relative_url)
      expect(page).to have_css(".bio .value", text: bio)
      within(".card-background") do
        expect(page).to have_link(
          I18n.t("js.review.view_image"),
          href: Discourse.store.cdn_url(card_background.url),
        )
      end
      within(".user-field") do
        expect(page).to have_css(".name", text: field.name)
        expect(page).to have_css(".value", text: "Example organization")
      end
    end

    review_page.select_bundled_action(reviewable, "user_profile-silence_user", bundle_index: 1)
    penalty = PageObjects::Modals::PenalizeUser.new("silence")
    penalty.fill_in_silence_reason("Repeated illegal offers")
    penalty.set_future_date("tomorrow")
    penalty.perform
    expect(penalty).to be_closed
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_reviewable_with_problem_confirmed_status(reviewable)
    admin_page = PageObjects::Pages::AdminUser.new
    admin_page.visit(target)
    expect(admin_page).to have_unsilence_button
  end

  it "lets a moderator remove current profile content from the Yes menu" do
    target.user_profile.update!(bio_raw: "Reported biography")
    sign_in(reporter)
    visit(target.relative_url)
    click_button(I18n.t("js.flagging_profile.action"))
    flag_modal.choose_type(:spam)
    flag_modal.confirm_flag
    expect(toasts).to have_success(I18n.t("js.flagging_profile.submitted"))

    edited_bio = "Biography edited after the report"
    target.user_profile.update!(bio_raw: edited_bio)
    sign_in(moderator)
    report = ReviewableFlaggedProfile.sole
    review_page.visit_reviewable(report)
    review_page.select_bundled_action(
      report,
      "user_profile-remove_profile_content",
      bundle_index: 1,
    )
    dialog = PageObjects::Components::Dialog.new
    expect(dialog).to have_content(I18n.t("reviewables.actions.remove_profile_content.confirm"))
    dialog.click_danger
    expect(review_page).to have_reviewable_with_problem_confirmed_status(report)
    visit(target.relative_url)
    expect(page).to have_no_content(edited_bio)
  end

  it "asks whether the profile is spam and lets a moderator dismiss the flag under No" do
    SiteSetting.review_queue_consistent_answers = true
    sign_in(reporter)
    PageObjects::Pages::User.new.visit(target)
    click_button(I18n.t("js.flagging_profile.action"))
    flag_modal.choose_type(:spam)
    flag_modal.confirm_flag
    expect(toasts).to have_success(I18n.t("js.flagging_profile.submitted"))

    sign_in(moderator)
    reviewable = ReviewableFlaggedProfile.sole
    review_page.visit_reviewable(reviewable)
    expect(review_page).to have_context_question(reviewable, "Is this profile spam?")
    within(".review-item__moderator-actions") do
      expect(page).to have_css(".reviewable-action-dropdown .select-kit-header", text: "Yes")
      expect(page).to have_css(".reviewable-action-dropdown .select-kit-header", text: "No")
    end
    review_page.select_bundled_action(
      reviewable,
      "user_profile-dismiss_profile_flag",
      bundle_index: 2,
    )
    expect(review_page).to have_reviewable_with_no_problem_found_status(reviewable)
  end

  it "shows the current flags and the removal warning when classifying a reopened report" do
    enable_dsa_reporting
    SiteSetting.review_queue_consistent_answers = true
    target.user_profile.update!(bio_raw: "Reported biography")
    report = Fabricate(:reviewable_flagged_profile, target: target.user_profile)
    report.perform(moderator, :dismiss_profile_flag)
    User::FlagProfile.call!(
      guardian: reporter.guardian,
      params: {
        username: target.username,
        flag_type_id: ReviewableScore.types[:inappropriate],
      },
    )

    sign_in(moderator)
    review_page.visit_reviewable(report)
    expect(review_page).to have_context_question(report, "Is this profile inappropriate?")
    expect(page).to have_css(".review-item__flag-badges", exact_text: "Inappropriate")

    review_page.select_bundled_action(
      report,
      "user_profile-remove_profile_content",
      bundle_index: 1,
    )
    modal = PageObjects::Modals::DsaModeration.new
    expect(modal).to have_action_title(I18n.t("reviewables.actions.remove_profile_content.title"))
    expect(modal).to have_content(I18n.t("reviewables.actions.remove_profile_content.confirm"))
    modal.confirm(I18n.t("reviewables.actions.remove_profile_content.title"))
    expect(review_page).to have_reviewable_with_problem_confirmed_status(report)
    review_page.visit_reviewable(report)
    expect(page).to have_css(".review-item__flag-badges", exact_text: "Inappropriate")
  end

  it "removes a closed profile report from the pending queue when deleting its last reporter" do
    enable_dsa_reporting
    admin = Fabricate(:admin)
    queued_post = Fabricate(:reviewable_queued_post, target_created_by: reporter)
    reopened = Fabricate(:reviewable_flagged_profile, target: target.user_profile)
    reopened.perform(admin, :dismiss_profile_flag)
    shared = Fabricate(:reviewable_flagged_profile)
    [reopened, shared].each do |report|
      User::FlagProfile.call!(
        guardian: reporter.guardian,
        params: {
          username: report.target.user.username,
          flag_type_id: ReviewableScore.types[:spam],
        },
      )
    end

    sign_in(admin)
    using_session(:other_tab) do
      sign_in(moderator)
      visit("/review")
      expect(review_page).to have_reviewables([queued_post, reopened, shared])
    end

    visit("/review")
    expect(review_page).to have_reviewables([queued_post, reopened, shared])
    review_page.select_bundled_action(queued_post, "delete_user")
    modal = PageObjects::Modals::DsaModeration.new
    expect(modal).to have_action_title("Delete @#{reporter.username}?")
    expect(modal.body).to have_no_text("Are you sure you want to delete @#{reporter.username}?")
    expect(modal).to have_classification
    modal.confirm("Delete user")

    expect(review_page).to have_reviewables([queued_post, shared])
    expect(review_page).to have_reviewable_with_pending_status(shared)
    expect(reopened.reload).to be_ignored

    using_session(:other_tab) do
      expect(review_page).to have_reviewables([queued_post, shared])
      expect(review_page).to have_reviewable_with_pending_status(shared)
    end
  end

  it "submits a DSA notice with the profile URL even when the member has no ordinary flags available" do
    enable_dsa_reporting
    SiteSetting.flag_post_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
    SiteSetting.external_system_avatars_url = "https://avatars.example.com/{username}.png"
    SiteSetting.unicode_usernames = true
    target.update!(username: "Mañana")
    notice_modal = PageObjects::Modals::DsaNotice.new
    reporter.activate
    sign_in(reporter)
    visit(target.relative_url)
    click_button(I18n.t("js.flagging_profile.action"))
    flag_modal.report_illegal_content
    expect(notice_modal).to have_field(
      I18n.t("js.dsa_notice.content_url"),
      with: URI.join(page.current_url, target.relative_url).to_s,
    )
    notice_modal.go_back
    expect(flag_modal).to have_no_selected_illegal_report
    flag_modal.report_illegal_content
    notice_modal.enter_report(
      name: "Alex Morgan",
      explanation:
        "This profile advertises counterfeit goods as authentic and directs buyers to send payment.",
    )
    notice_modal.accept_declaration
    notice_modal.submit_report
    expect(notice_modal).to have_confirmation
  end
end
