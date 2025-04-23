#frozen_string_literal: true

describe "Admin Backups Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  let(:backups_page) { PageObjects::Pages::AdminBackups.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  let(:root_directory) { setup_local_backups }

  def create_backups
    create_local_backup_file(
      root_directory: root_directory,
      db_name: "default",
      filename: "b.tar.gz",
      last_modified: "2024-07-13T15:10:00Z",
      size_in_bytes: 10,
    )
    create_local_backup_file(
      root_directory: root_directory,
      db_name: "default",
      filename: "old.tar.gz",
      last_modified: "2024-06-01T13:10:00Z",
      size_in_bytes: 5,
    )
  end

  before do
    sign_in(current_user)
    create_backups
    BackupRestore::LocalBackupStore.stubs(:base_directory).returns(
      root_directory + "/" + RailsMultisite::ConnectionManagement.current_db,
    )
  end
  after { teardown_local_backups(root_directory: root_directory) }

  it "shows a list of backups" do
    backups_page.visit_page
    expect(backups_page).to have_backup_listed("b.tar.gz")
    expect(backups_page).to have_backup_listed("old.tar.gz")
  end

  it "can download a backup, which sends an email" do
    backups_page.visit_page
    backups_page.download_backup("b.tar.gz")
    expect(page).to have_content(I18n.t("admin_js.admin.backups.operations.download.alert"))
    expect_job_enqueued(
      job: :download_backup_email,
      args: {
        user_id: current_user.id,
        backup_file_path: Discourse.base_url + "/admin/backups/b.tar.gz",
      },
    )
  end

  it "can delete a backup" do
    backups_page.visit_page
    backups_page.delete_backup("b.tar.gz")
    dialog.click_yes
    expect(backups_page).to have_no_backup_listed("b.tar.gz")
  end

  it "can restore a backup" do
    backups_page.visit_page
    backups_page.expand_backup_row_menu("b.tar.gz")
    expect(backups_page).to have_css(backups_page.row_button_selector("restore"))
  end

  it "can toggle read-only mode" do
    backups_page.visit_page
    backups_page.toggle_read_only
    dialog.click_yes
    expect(page).to have_content(I18n.t("js.read_only_mode.enabled"))
    backups_page.toggle_read_only
    expect(page).to have_no_content(I18n.t("js.read_only_mode.enabled"))
  end

  it "can see backup site settings" do
    backups_page.visit_page
    backups_page.click_tab("settings")
    expect(settings_page).to have_setting("enable_backups")
  end

  it "shows only settings tab when backups are not enabled" do
    SiteSetting.enable_backups = false
    backups_page.visit_page

    expect(backups_page).to have_no_read_only_button
    expect(backups_page).to have_no_backup_button
    expect(backups_page).to have_no_backup_item_more_menu
  end
end
