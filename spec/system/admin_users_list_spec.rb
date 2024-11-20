# frozen_string_literal: true

describe "Admin Users Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:another_admin) { Fabricate(:admin) }
  fab!(:users) { Fabricate.times(3, :user) }

  let(:admin_users_page) { PageObjects::Pages::AdminUsers.new }

  before { sign_in(current_user) }

  describe "bulk user delete" do
    let(:confirmation_modal) { PageObjects::Modals::BulkUserDeleteConfirmation.new }

    it "disables checkboxes for users that can't be deleted" do
      admin_users_page.visit

      admin_users_page.bulk_select_button.click

      expect(admin_users_page.user_row(current_user.id).bulk_select_checkbox.disabled?).to eq(true)
      expect(admin_users_page.user_row(another_admin.id).bulk_select_checkbox.disabled?).to eq(true)
      expect(admin_users_page.user_row(users[0].id).bulk_select_checkbox.disabled?).to eq(false)

      admin_users_page.user_row(another_admin.id).bulk_select_checkbox.hover
      expect(PageObjects::Components::Tooltips.new("bulk-delete-unavailable-reason")).to be_present(
        text: I18n.t("admin_js.admin.users.bulk_actions.admin_cant_be_deleted"),
      )
    end

    it "has a button that toggles the bulk select checkboxes" do
      admin_users_page.visit

      expect(admin_users_page).to have_users(users.map(&:id))

      expect(admin_users_page.user_row(users[0].id)).to have_no_bulk_select_checkbox
      expect(admin_users_page.user_row(users[1].id)).to have_no_bulk_select_checkbox
      expect(admin_users_page.user_row(users[2].id)).to have_no_bulk_select_checkbox

      admin_users_page.bulk_select_button.click

      expect(admin_users_page.user_row(users[0].id)).to have_bulk_select_checkbox
      expect(admin_users_page.user_row(users[1].id)).to have_bulk_select_checkbox
      expect(admin_users_page.user_row(users[2].id)).to have_bulk_select_checkbox

      expect(admin_users_page).to have_no_bulk_actions_dropdown

      admin_users_page.user_row(users[0].id).bulk_select_checkbox.click

      expect(admin_users_page).to have_bulk_actions_dropdown

      admin_users_page.user_row(users[1].id).bulk_select_checkbox.click
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
        user: users[0],
        position: 1,
        total: 2,
      )
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: users[1],
        position: 2,
        total: 2,
      )
      expect(confirmation_modal).to have_no_error_log_entries

      confirmation_modal.close
      deleted_ids = users[0..1].map(&:id)
      expect(admin_users_page).to have_no_users(deleted_ids)
      expect(User.where(id: deleted_ids).count).to eq(0)
    end

    it "remembers selected users when the user list refreshes due to search" do
      admin_users_page.visit
      admin_users_page.bulk_select_button.click
      admin_users_page.search_input.fill_in(with: users[0].username)
      admin_users_page.user_row(users[0].id).bulk_select_checkbox.click

      admin_users_page.search_input.fill_in(with: users[1].username)
      admin_users_page.user_row(users[1].id).bulk_select_checkbox.click

      admin_users_page.search_input.fill_in(with: "")

      expect(admin_users_page).to have_users(users.map(&:id))
      expect(admin_users_page.user_row(users[0].id).bulk_select_checkbox).to be_checked
      expect(admin_users_page.user_row(users[1].id).bulk_select_checkbox).to be_checked
      expect(admin_users_page.user_row(users[2].id).bulk_select_checkbox).not_to be_checked

      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click

      expect(confirmation_modal).to be_open
      confirmation_modal.fill_in_confirmation_phase(user_count: 2)
      confirmation_modal.confirm_button.click
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: users[0],
        position: 1,
        total: 2,
      )
      expect(confirmation_modal).to have_successful_log_entry_for_user(
        user: users[1],
        position: 2,
        total: 2,
      )
      confirmation_modal.close

      deleted_ids = users[0..1].map(&:id)
      expect(admin_users_page).to have_no_users(deleted_ids)
      expect(User.where(id: deleted_ids).count).to eq(0)
    end

    it "displays an error message if bulk delete fails" do
      admin_users_page.visit
      admin_users_page.bulk_select_button.click

      admin_users_page.user_row(users[0].id).bulk_select_checkbox.click
      admin_users_page.bulk_actions_dropdown.expand
      admin_users_page.bulk_actions_dropdown.option(".bulk-delete").click
      confirmation_modal.fill_in_confirmation_phase(user_count: 1)

      users[0].update!(admin: true)

      confirmation_modal.confirm_button.click
      expect(confirmation_modal).to have_error_log_entry(
        I18n.t("js.generic_error_with_reason", error: I18n.t("user.cannot_bulk_delete")),
      )
      confirmation_modal.close
      expect(admin_users_page).to have_users([users[0].id])
    end
  end
end
