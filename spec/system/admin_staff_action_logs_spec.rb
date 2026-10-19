# frozen_string_literal: true

describe "Admin staff action logs" do
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

  fab!(:history_with_html_value) do
    Fabricate(
      :user_history,
      action: UserHistory.actions[:change_name],
      previous_value: "Old name",
      new_value: %(<img src=x onerror="alert('xss')">),
    )
  end

  let(:staff_action_logs_page) { PageObjects::Pages::AdminStaffActionLogs.new }

  before { sign_in(current_user) }

  it "shows details for an action" do
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    row = staff_action_logs_page.log_row(history_1)
    expect(row).to contain_text(
      I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
      useInnerText: true,
    )
    expect(row).to contain_text("enforce_second_factor", useInnerText: true)
    expect(row).to contain_text(
      I18n.t("admin_js.admin.logs.staff_actions.new_value", "all"),
      useInnerText: true,
    )
    expect(row).to contain_text(
      I18n.t("admin_js.admin.logs.staff_actions.previous_value", "no"),
      useInnerText: true,
    )
    row = staff_action_logs_page.log_row(history_2)
    expect(row).to contain_text(
      I18n.t("admin_js.admin.logs.staff_actions.actions.topic_closed"),
      useInnerText: true,
    )
    expect(
      row.locator("[data-link-topic-id='#{history_2.topic_id}']").filter(visible: true),
    ).not_to have_count(0)
  end

  it "keeps staff action details as text" do
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(staff_action_logs_page).to have_no_injected_detail_element(history_with_html_value)
    expect(staff_action_logs_page).to have_details_text(
      history_with_html_value,
      %(<img src=x onerror="alert('xss')">),
    )
  end

  it "can filter by type of action" do
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(staff_action_logs_page).to have_log_row(history_1)
    expect(staff_action_logs_page).to have_log_row(history_2)
    expect(staff_action_logs_page).to have_log_row(history_3)

    staff_action_logs_page.filter_by_action(:change_site_setting)

    expect(
      browser_root.locator(".staff-action-logs-filters .filter").filter(visible: true),
    ).to contain_text(
      [
        browser_text_pattern(
          I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
        ),
      ],
      useInnerText: true,
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
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    staff_action_logs_page.filter_by_action(:change_site_setting)

    expect(
      browser_root.locator(".staff-action-logs-filters .filter").filter(visible: true),
    ).to contain_text(
      [
        browser_text_pattern(
          I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
        ),
      ],
      useInnerText: true,
    )

    expect(
      browser_root.locator(".export-staff-action-logs").filter(visible: true),
    ).not_to have_count(0)

    expect do
      staff_action_logs_page.click_export_button

      expect(browser_content).to contain_text(
        browser_text_pattern(I18n.t("admin_js.admin.export_csv.success")),
        useInnerText: true,
      )
    end.to change { Jobs::ExportCsvFile.jobs.size }.by(1)

    job = Jobs::ExportCsvFile.jobs.last
    args = job["args"].first["args"]
    expect(args).to include({ "action_id" => UserHistory.actions[:change_site_setting].to_s })
  end

  it "displays no result" do
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    staff_action_logs_page.filter_by_action(:toggle_flag)
    expect(browser_content).to contain_text(
      browser_text_pattern(I18n.t("js.search.no_results")),
      useInnerText: true,
    )
  end

  it "can show details for an action" do
    history_1.update!(
      details:
        "Discourse is automatically enabling this for all our hosted customers, please see https://meta.discourse.org/t/123 for more information.",
    )
    browser_page
      .goto("/admin/logs/staff_action_logs")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    browser_root
      .locator("#{staff_action_logs_page.log_row_selector(history_1)} .col.value.details a")
      .filter(visible: true)
      .click
    expect(PageObjects::Modals::Base.new).to have_displayed_content(history_1.details)
  end

  describe "date time filting" do
    let!(:histories) do
      (1..10).map do |i|
        Fabricate(:user_history, action: UserHistory.actions[:suspend_user], created_at: i.days.ago)
      end
    end

    it "can see filtered logs" do
      browser_page
        .goto("/admin/logs/staff_action_logs")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      staff_action_logs_page.fill_date_filter_from(7.days.ago)
      staff_action_logs_page.fill_date_filter_to(2.days.ago)

      [1, 2, 8, 9, 10].each do |i|
        expect(staff_action_logs_page).to have_no_log_row(histories[i - 1])
      end
      [3, 4, 5, 6, 7].each { |i| expect(staff_action_logs_page).to have_log_row(histories[i - 1]) }
    end

    it "can export filtered logs" do
      browser_page
        .goto("/admin/logs/staff_action_logs")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      staff_action_logs_page.fill_date_filter_from(7.days.ago)
      staff_action_logs_page.fill_date_filter_to(2.days.ago)

      expect do
        staff_action_logs_page.click_export_button

        expect(browser_content).to contain_text(
          browser_text_pattern(I18n.t("admin_js.admin.export_csv.success")),
          useInnerText: true,
        )
      end.to change { Jobs::ExportCsvFile.jobs.size }.by(1)

      job = Jobs::ExportCsvFile.jobs.last
      args = job["args"].first["args"]
      expect(args).to include("start_date")
      expect(args).to include("end_date")
    end
  end
end
