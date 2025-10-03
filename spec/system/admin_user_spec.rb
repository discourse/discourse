# frozen_string_literal: true

describe "Admin User Page", type: :system do
  fab!(:current_user, :admin)

  let(:admin_user_page) { PageObjects::Pages::AdminUser.new }
  let(:suspend_user_modal) { PageObjects::Modals::PenalizeUser.new("suspend") }
  let(:silence_user_modal) { PageObjects::Modals::PenalizeUser.new("silence") }

  before { sign_in(current_user) }

  context "when visiting an admin's page" do
    fab!(:admin)

    before { admin_user_page.visit(admin) }

    it "doesn't display the suspend or silence buttons" do
      expect(admin_user_page).to have_no_suspend_button
      expect(admin_user_page).to have_no_silence_button
    end
  end

  context "when visiting a moderator's page" do
    fab!(:moderator)

    before { admin_user_page.visit(moderator) }

    it "doesn't display the suspend or silence buttons" do
      expect(admin_user_page).to have_no_suspend_button
      expect(admin_user_page).to have_no_silence_button
    end
  end

  context "when visting a regular user's page" do
    fab!(:user) { Fabricate(:user, ip_address: "93.123.44.90") }
    fab!(:similar_user) { Fabricate(:user, ip_address: user.ip_address) }
    fab!(:another_mod) { Fabricate(:moderator, ip_address: user.ip_address) }
    fab!(:another_admin) { Fabricate(:admin, ip_address: user.ip_address) }

    before { admin_user_page.visit(user) }

    it "can list accounts with identical IPs" do
      find(".ip-lookup-trigger").click

      expect(page).to have_content("#{I18n.t("js.ip_lookup.other_accounts")}\n3")

      table = page.find(".other-accounts table")
      expect(table).to have_content(similar_user.username)
      expect(table).to have_content(another_mod.username)
      expect(table).to have_content(another_admin.username)
    end

    it "displays the suspend and silence buttons" do
      expect(admin_user_page).to have_suspend_button
      expect(admin_user_page).to have_silence_button
    end

    it "displays username in the title" do
      expect(page).to have_css(".display-row.username")
      expect(page.title).to eq("#{user.username} - Users - Admin - Discourse")
    end

    describe "the suspend user modal" do
      it "displays the list of users who share the same IP but are not mods or admins" do
        admin_user_page.click_suspend_button

        expect(suspend_user_modal.similar_users).to contain_exactly(similar_user.username)
        expect(admin_user_page.similar_users_warning).to include(
          I18n.t("admin_js.admin.user.other_matches", count: 1, username: user.username),
        )
      end

      it "suspends and unsuspends the user" do
        admin_user_page.click_suspend_button
        suspend_user_modal.fill_in_suspend_reason("spamming")
        suspend_user_modal.set_future_date("tomorrow")
        suspend_user_modal.perform
        expect(suspend_user_modal).to be_closed

        expect(page).to have_css(".suspension-info")

        admin_user_page.click_unsuspend_button
        expect(page).not_to have_css(".suspension-info")
      end

      it "displays error when used is already suspended" do
        admin_user_page.click_suspend_button
        suspend_user_modal.fill_in_suspend_reason("spamming")
        suspend_user_modal.set_future_date("tomorrow")

        user.update!(suspended_till: 1.day.from_now)
        StaffActionLogger.new(current_user).log_user_suspend(user, "spamming")

        suspend_user_modal.perform

        expect(suspend_user_modal).to have_error_message(
          "User was already suspended by #{current_user.username} just now.",
        )
        expect(suspend_user_modal).to be_open
      end
    end

    describe "the silence user modal" do
      it "displays the list of users who share the same IP but are not mods or admins" do
        admin_user_page.click_silence_button

        expect(silence_user_modal.similar_users).to contain_exactly(similar_user.username)
        expect(admin_user_page.similar_users_warning).to include(
          I18n.t("admin_js.admin.user.other_matches", count: 1, username: user.username),
        )
      end

      it "silence and unsilence the user" do
        admin_user_page.click_silence_button

        silence_user_modal.fill_in_silence_reason("spamming")
        silence_user_modal.set_future_date("tomorrow")
        silence_user_modal.perform

        expect(silence_user_modal).to be_closed
        expect(page).to have_css(".silence-info")

        admin_user_page.click_unsilence_button
        expect(page).not_to have_css(".silence-info")
      end
    end
  end

  context "when logged in as a moderator" do
    fab!(:current_user, :moderator)

    context "when visiting a regular user's page" do
      fab!(:user)

      before { admin_user_page.visit(user) }

      context "when moderators_change_trust_levels setting is enabled" do
        before { SiteSetting.moderators_change_trust_levels = true }

        it "the dropdown to change trust level is enabled" do
          expect(admin_user_page).to have_change_trust_level_dropdown_enabled
        end
      end

      context "when moderators_change_trust_levels setting is disabled" do
        before { SiteSetting.moderators_change_trust_levels = false }

        it "the dropdown to change trust level is disabled" do
          expect(admin_user_page).to have_change_trust_level_dropdown_disabled
        end
      end
    end
  end
end
