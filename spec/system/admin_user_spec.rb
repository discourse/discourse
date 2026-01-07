# frozen_string_literal: true

describe "Admin User Page", type: :system do
  fab!(:current_user, :admin)

  let(:admin_users_page) { PageObjects::Pages::AdminUsers.new }
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

  context "when visiting a regular user's page" do
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

    describe "the upcoming changes section" do
      fab!(:group1) { Fabricate(:group, name: "test_group_1") }
      fab!(:group2) { Fabricate(:group, name: "test_group_2") }

      before do
        SiteSetting.enable_upcoming_changes = true

        mock_upcoming_change_metadata(
          {
            enable_upload_debug_mode: {
              impact: "feature,all_members",
              status: :beta,
              impact_type: "feature",
              impact_role: "all_members",
            },
          },
        )
      end

      context "when the change is enabled for everyone" do
        before { SiteSetting.enable_upload_debug_mode = true }

        it "displays the upcoming change with enabled status and correct reason" do
          admin_user_page.visit(user)
          expect(admin_user_page).to have_upcoming_change("enable_upload_debug_mode")
          expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to be_enabled
          expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to have_reason(
            "enabled_for_everyone",
          )
          expect(
            admin_user_page.upcoming_change("enable_upload_debug_mode"),
          ).to have_no_specific_groups
        end
      end

      context "when the change is disabled for everyone" do
        before { SiteSetting.enable_upload_debug_mode = false }

        it "displays the upcoming change with disabled status and correct reason" do
          admin_user_page.visit(user)
          expect(admin_user_page).to have_upcoming_change("enable_upload_debug_mode")
          expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to be_disabled
          expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to have_reason(
            "enabled_for_no_one",
          )
          expect(
            admin_user_page.upcoming_change("enable_upload_debug_mode"),
          ).to have_no_specific_groups
        end
      end

      context "when the change is enabled for specific groups" do
        before do
          SiteSetting.enable_upload_debug_mode = true
          Fabricate(
            :site_setting_group,
            name: "enable_upload_debug_mode",
            group_ids: "#{group1.id}|#{group2.id}",
          )
        end

        context "when the user belongs to one of those groups" do
          before { group1.add(user) }

          it "displays the upcoming change with enabled status, correct reason, and specific groups" do
            admin_user_page.visit(user)
            expect(admin_user_page).to have_upcoming_change("enable_upload_debug_mode")
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to be_enabled
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to have_reason(
              "in_specific_groups",
            )
            expect(
              admin_user_page.upcoming_change("enable_upload_debug_mode"),
            ).to have_specific_groups(["test_group_1"])
          end
        end

        context "when the user belongs to multiple groups" do
          before do
            group1.add(user)
            group2.add(user)
          end

          it "displays the upcoming change with all groups" do
            admin_user_page.visit(user)
            expect(admin_user_page).to have_upcoming_change("enable_upload_debug_mode")
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to be_enabled
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to have_reason(
              "in_specific_groups",
            )
            expect(
              admin_user_page.upcoming_change("enable_upload_debug_mode"),
            ).to have_specific_groups(%w[test_group_1 test_group_2])
          end
        end

        context "when the user does not belong to any of those groups" do
          it "displays the upcoming change with disabled status, correct reason, and no specific groups" do
            admin_user_page.visit(user)
            expect(admin_user_page).to have_upcoming_change("enable_upload_debug_mode")
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to be_disabled
            expect(admin_user_page.upcoming_change("enable_upload_debug_mode")).to have_reason(
              "not_in_specific_groups",
            )
            expect(
              admin_user_page.upcoming_change("enable_upload_debug_mode"),
            ).to have_no_specific_groups
          end
        end
      end
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

      context "when moderators_change_trust_levels setting is enabled" do
        before { SiteSetting.moderators_change_trust_levels = true }

        it "the dropdown to change trust level is enabled" do
          admin_user_page.visit(user)

          expect(admin_user_page).to have_change_trust_level_dropdown_enabled
        end
      end

      context "when moderators_change_trust_levels setting is disabled" do
        before { SiteSetting.moderators_change_trust_levels = false }

        it "the dropdown to change trust level is disabled" do
          admin_user_page.visit(user)

          expect(admin_user_page).to have_change_trust_level_dropdown_disabled
        end
      end
    end
  end

  context "when navigating to a user's page from the list" do
    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    it "displays the groups correctly" do
      admin_users_page.visit

      # navigate to the user page
      admin_users_page.user_row(user.id).username.click

      # ensure the automatic groups are displayed
      page.find(".admin-user__automatic-groups").has_text?("trust_level")
    end

    describe "with user action logs" do
      let(:staff_action_logs_page) { PageObjects::Pages::AdminStaffActionLogs.new }

      fab!(:user_a, :user)
      fab!(:user_a_silenced) do
        Fabricate(:user_history, action: UserHistory.actions[:silence_user], target_user: user_a)
      end
      fab!(:user_b, :user)
      fab!(:user_b_silenced) do
        Fabricate(:user_history, action: UserHistory.actions[:silence_user], target_user: user_b)
      end

      # Relates to
      # meta.discourse.org/t/-/387508
      it "refreshes the filter when navigating thought the action logs button" do
        admin_users_page.visit
        admin_users_page.user_row(user_a.id).username.click

        admin_user_page.click_action_logs_button
        expect(staff_action_logs_page).to have_log_row(user_a_silenced)
        expect(staff_action_logs_page).to have_no_log_row(user_b_silenced)

        page.go_back # navigate back to user page
        page.go_back # navigate back to user list

        admin_users_page.user_row(user_b.id).username.click
        admin_user_page.click_action_logs_button

        expect(staff_action_logs_page).to have_log_row(user_b_silenced)
        expect(staff_action_logs_page).to have_no_log_row(user_a_silenced)
      end
    end
  end
end
