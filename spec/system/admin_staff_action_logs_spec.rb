# frozen_string_literal: true

describe "Admin staff action logs", type: :system do
  fab!(:current_user, :admin)
  fab!(:history_1) do
    Fabricate(
      :site_setting_change_history,
      subject: "enforce_second_factor",
      previous_value: "no",
      new_value: "all",
    )
  end
  fab!(:history_2, :topic_closed_change_history)
  fab!(:history_3) do
    Fabricate(
      :user_history,
      action: UserHistory.actions[:custom_staff],
      details: "flag updated",
      custom_type: "update_flag",
    )
  end
  let(:staff_action_logs_page) { PageObjects::Pages::AdminStaffActionLogs.new }

  before { sign_in(current_user) }

  it "shows details for an action" do
    visit "/admin/logs/staff_action_logs"

    expect(staff_action_logs_page.log_row(history_1)).to have_content(
      I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
    ).and have_content("enforce_second_factor").and have_content(
                  I18n.t("admin_js.admin.logs.staff_actions.new_value", "all"),
                ).and have_content(I18n.t("admin_js.admin.logs.staff_actions.previous_value", "no"))

    expect(staff_action_logs_page.log_row(history_2)).to have_content(
      I18n.t("admin_js.admin.logs.staff_actions.actions.topic_closed"),
    ).and have_css("[data-link-topic-id='#{history_2.topic_id}']")
  end

  it "can filter by type of action" do
    visit "/admin/logs/staff_action_logs"

    expect(staff_action_logs_page).to have_log_row(history_1)
    expect(staff_action_logs_page).to have_log_row(history_2)
    expect(staff_action_logs_page).to have_log_row(history_3)

    staff_action_logs_page.filter_by_action(:change_site_setting)

    expect(page).to have_css(
      ".staff-action-logs-filters .filter",
      text: I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
    )

    expect(staff_action_logs_page).to have_log_row(history_1)
    expect(staff_action_logs_page).to have_no_log_row(history_2)
    expect(staff_action_logs_page).to have_no_log_row(history_3)

    staff_action_logs_page.clear_filter

    staff_action_logs_page.filter_by_action(:update_flag)

    expect(staff_action_logs_page).to have_no_log_row(history_1)
    expect(staff_action_logs_page).to have_no_log_row(history_2)
    expect(staff_action_logs_page).to have_log_row(history_3)
  end

  it "can export filtered logs" do
    visit "/admin/logs/staff_action_logs"

    staff_action_logs_page.filter_by_action(:change_site_setting)

    expect(page).to have_css(
      ".staff-action-logs-filters .filter",
      text: I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
    )

    expect(page).to have_css(".export-staff-action-logs")

    expect do
      staff_action_logs_page.click_export_button

      expect(page).to have_text(I18n.t("admin_js.admin.export_csv.success"))
    end.to change { Jobs::ExportCsvFile.jobs.size }.by(1)

    job = Jobs::ExportCsvFile.jobs.last
    args = job["args"].first["args"]
    expect(args).to include({ "action_id" => UserHistory.actions[:change_site_setting].to_s })
  end

  it "displays no result" do
    visit "/admin/logs/staff_action_logs"
    staff_action_logs_page.filter_by_action(:toggle_flag)
    expect(page).to have_text(I18n.t("js.search.no_results"))
  end

  it "can show details for an action" do
    history_1.update!(
      details:
        "Discourse is automatically enabling this for all our hosted customers, please see https://meta.discourse.org/t/123 for more information.",
    )
    visit "/admin/logs/staff_action_logs"

    find("#{staff_action_logs_page.log_row_selector(history_1)} .col.value.details a").click
    expect(PageObjects::Modals::Base.new).to have_content(history_1.details)
  end

  describe "date time filting" do
    let!(:histories) do
      (1..10).map do |i|
        Fabricate(:user_history, action: UserHistory.actions[:suspend_user], created_at: i.days.ago)
      end
    end

    it "can see filtered logs" do
      visit "/admin/logs/staff_action_logs"

      staff_action_logs_page.fill_date_filter_from(7.days.ago)
      staff_action_logs_page.fill_date_filter_to(2.days.ago)

      [1, 2, 8, 9, 10].each do |i|
        expect(staff_action_logs_page).to have_no_log_row(histories[i - 1])
      end
      [3, 4, 5, 6, 7].each { |i| expect(staff_action_logs_page).to have_log_row(histories[i - 1]) }
    end

    it "can export filtered logs" do
      visit "/admin/logs/staff_action_logs"

      staff_action_logs_page.fill_date_filter_from(7.days.ago)
      staff_action_logs_page.fill_date_filter_to(2.days.ago)

      expect do
        staff_action_logs_page.click_export_button

        expect(page).to have_text(I18n.t("admin_js.admin.export_csv.success"))
      end.to change { Jobs::ExportCsvFile.jobs.size }.by(1)

      job = Jobs::ExportCsvFile.jobs.last
      args = job["args"].first["args"]
      expect(args).to include("start_date")
      expect(args).to include("end_date")
    end
  end
end
