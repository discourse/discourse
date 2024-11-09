# frozen_string_literal: true

describe "Admin Users Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:users) { Fabricate.times(3, :user) }

  let(:admin_users_page) { PageObjects::Pages::AdminUsers.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(current_user) }

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

    expect(dialog).to be_open
    dialog.click_danger

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

    expect(dialog).to be_open
    dialog.click_danger

    deleted_ids = users[0..1].map(&:id)
    expect(admin_users_page).to have_no_users(deleted_ids)
    expect(User.where(id: deleted_ids).count).to eq(0)
  end
end
