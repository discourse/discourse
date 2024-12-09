# frozen_string_literal: true

describe "Admin Users Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:another_admin) { Fabricate(:admin) }
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }

  let(:admin_users_page) { PageObjects::Pages::AdminUsers.new }

  before { sign_in(current_user) }

  it "show correct breadcrumbs" do
    admin_users_page.visit
    expect(admin_users_page).to have_correct_breadcrumbs
  end

  describe "bulk user delete" do
    let(:confirmation_modal) { PageObjects::Modals::BulkUserDeleteConfirmation.new }

    it "disables checkboxes for users that can't be deleted" do
      admin_users_page.visit

      admin_users_page.bulk_select_button.click

      expect(admin_users_page.user_row(current_user.id).bulk_select_checkbox.disabled?).to eq(true)
      expect(admin_users_page.user_row(another_admin.id).bulk_select_checkbox.disabled?).to eq(true)
      expect(admin_users_page.user_row(user_1.id).bulk_select_checkbox.disabled?).to eq(false)

      admin_users_page.user_row(another_admin.id).bulk_select_checkbox.hover
      expect(PageObjects::Components::Tooltips.new("bulk-delete-unavailable-reason")).to be_present(
        text: I18n.t("admin_js.admin.users.bulk_actions.admin_cant_be_deleted"),
      )
    end

    it "has a button that toggles the bulk select checkboxes" do
      admin_users_page.visit

      expect(admin_users_page).to have_users([user_1.id, user_2.id, user_3.id])

      expect(admin_users_page.user_row(user_1.id)).to have_no_bulk_select_checkbox
      expect(admin_users_page.user_row(user_2.id)).to have_no_bulk_select_checkbox
      expect(admin_users_page.user_row(user_3.id)).to have_no_bulk_select_checkbox

      admin_users_page.bulk_select_button.click

      expect(admin_users_page.user_row(user_1.id)).to have_bulk_select_checkbox
      expect(admin_users_page.user_row(user_2.id)).to have_bulk_select_checkbox
      expect(admin_users_page.user_row(user_3.id)).to have_bulk_select_checkbox

      expect(admin_users_page).to have_no_bulk_actions_dropdown

      admin_users_page.user_row(user_1.id).bulk_select_checkbox.click

      expect(admin_users_page).to have_bulk_actions_dropdown

      admin_users_page.user_row(user_2.id).bulk_select_checkbox.click
      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click

      expect(confirmation_modal).to be_open
      expect(confirmation_modal).to have_confirm_button_disabled

      confirmation_modal.fill_in_confirmation_phase(user_count: 3)
      expect(confirmation_modal).to have_confirm_button_disabled

      confirmation_modal.fill_in_confirmation_phase(user_count: 2)
      expect(confirmation_modal).to have_confirm_button_enabled

      confirmation_modal.confirm_button.click

      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: user_1,
        position: 1,
        total: 2,
      )
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: user_2,
        position: 2,
        total: 2,
      )
      expect(confirmation_modal).to have_no_error_log_entries

      confirmation_modal.close
      expect(admin_users_page).to have_no_users([user_1.id, user_2.id])
      expect(User.where(id: [user_1.id, user_2.id]).count).to eq(0)
    end

    it "remembers selected users when the user list refreshes due to search" do
      admin_users_page.visit
      admin_users_page.bulk_select_button.click
      admin_users_page.search_input.fill_in(with: user_1.username)
      admin_users_page.user_row(user_1.id).bulk_select_checkbox.click

      admin_users_page.search_input.fill_in(with: user_2.username)
      admin_users_page.user_row(user_2.id).bulk_select_checkbox.click

      admin_users_page.search_input.fill_in(with: "")

      expect(admin_users_page).to have_users([user_1.id, user_2.id, user_3.id])
      expect(admin_users_page.user_row(user_1.id).bulk_select_checkbox).to be_checked
      expect(admin_users_page.user_row(user_2.id).bulk_select_checkbox).to be_checked
      expect(admin_users_page.user_row(user_3.id).bulk_select_checkbox).not_to be_checked

      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click

      expect(confirmation_modal).to be_open
      confirmation_modal.fill_in_confirmation_phase(user_count: 2)
      confirmation_modal.confirm_button.click
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: user_1,
        position: 1,
        total: 2,
      )
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: user_2,
        position: 2,
        total: 2,
      )
      confirmation_modal.close

      expect(admin_users_page).to have_no_users([user_1.id, user_2.id])
      expect(User.where(id: [user_1.id, user_2.id]).count).to eq(0)
    end

    it "displays an error message if bulk delete fails" do
      admin_users_page.visit
      admin_users_page.bulk_select_button.click

      admin_users_page.user_row(user_1.id).bulk_select_checkbox.click
      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click
      confirmation_modal.fill_in_confirmation_phase(user_count: 1)

      user_1.update!(admin: true)

      confirmation_modal.confirm_button.click
      expect(confirmation_modal).to have_error_log_entry(
        I18n.t("js.generic_error_with_reason", error: I18n.t("user.cannot_bulk_delete")),
      )
      confirmation_modal.close
      expect(admin_users_page).to have_users([user_1.id])
    end
  end

  context "when visiting an admin's page" do
    it "shows list of active users" do
      admin_users_page.visit
      expect(admin_users_page).to have_active_tab("active")
      expect(page).to have_css(".directory-table__cell.username")
      expect(admin_users_page).to have_users(
        [current_user.id, another_admin.id, user_1.id, user_2.id, user_3.id],
      )
    end

    it "shows list of suspended users" do
      admin_users_page.visit
      admin_users_page.click_tab("suspended")
      expect(admin_users_page).to have_active_tab("suspended")
      expect(admin_users_page).to have_none_users
    end

    it "shows list of silenced users" do
      admin_users_page.visit
      user_1.update!(silenced_till: 1.day.from_now)
      admin_users_page.click_tab("silenced")
      expect(admin_users_page).to have_active_tab("silenced")
      expect(page).to have_css(".users-list.silenced")
      expect(admin_users_page).to have_users([user_1.id])
    end

    it "shows emails" do
      admin_users_page.visit
      expect(admin_users_page).to have_no_emails
      admin_users_page.click_show_emails
      expect(admin_users_page).to have_emails
    end

    it "redirects to groups page" do
      admin_users_page.visit
      admin_users_page.click_tab("groups")
      expect(page).to have_current_path("/g")
    end

    it "redirect to invites page" do
      admin_users_page.visit
      admin_users_page.click_send_invites
      expect(page).to have_current_path("/u/#{current_user.username}/invited/pending")
    end

    it "allows to export users" do
      admin_users_page.visit
      admin_users_page.click_export
      expect(page).to have_css(".dialog-body")
      expect(page).to have_content(I18n.t("admin_js.admin.export_csv.success"))
    end

    it "has an option to block IPs and emails" do
      users.first.update!(ip_address: IPAddr.new("44.22.11.33"))

      admin_users_page.visit
      admin_users_page.bulk_select_button.click

      admin_users_page.user_row(users.first.id).bulk_select_checkbox.click
      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click
      confirmation_modal.fill_in_confirmation_phase(user_count: 1)
      confirmation_modal.block_ip_and_email_checkbox.click
      confirmation_modal.confirm_button.click

      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: users.first,
        position: 1,
        total: 1,
      )
      expect(
        ScreenedIpAddress.exists?(
          ip_address: users.first.ip_address,
          action_type: ScreenedIpAddress.actions[:block],
        ),
      ).to be_truthy
      expect(
        ScreenedEmail.exists?(email: users.first.email, action_type: ScreenedEmail.actions[:block]),
      ).to be_truthy
    end
  end
end
