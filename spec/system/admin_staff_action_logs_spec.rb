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

  it "shows scheduled restrictions alongside their reasons" do
    user = Fabricate(:user, username: "example_user")
    created_at = 3.hours.ago
    suspension =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:suspend_user],
        acting_user: current_user,
        target_user: user,
        details: "Spamming",
        created_at: created_at,
        expires_at: created_at + 7.days,
      )
    silence =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:silence_user],
        acting_user: current_user,
        target_user: user,
        details: "Advertising",
        created_at: 2.days.ago,
        expires_at: 1.day.ago,
      )
    indefinite =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:silence_user],
        acting_user: current_user,
        target_user: user,
        details: "Repeated spam",
        created_at: 3.days.ago,
        expires_at: 1000.years.from_now,
      )
    legacy =
      Fabricate(
        :user_history,
        action: UserHistory.actions[:suspend_user],
        acting_user: current_user,
        target_user: user,
        details: "Spamming",
        created_at: 5.days.ago,
      )

    filters = { target_user: user.username }.to_json
    visit "/admin/logs/staff_action_logs?filters=#{CGI.escape(filters)}"

    expect(staff_action_logs_page.log_row(suspension)).to have_content("Spamming")
    expect(staff_action_logs_page.log_row(suspension)).to have_content("Scheduled duration: 7 days")
    expect(staff_action_logs_page.log_row(suspension)).to have_content("Scheduled expiry:")
    expect(staff_action_logs_page.log_row(silence)).to have_content("Scheduled duration: 1 day")
    expect(staff_action_logs_page.log_row(indefinite)).to have_content(
      "Scheduled duration: Indefinite",
    )
    expect(staff_action_logs_page.log_row(indefinite)).to have_no_content("Scheduled expiry:")
    expect(staff_action_logs_page.log_row(legacy)).to have_content("Spamming")
    expect(staff_action_logs_page.log_row(legacy)).to have_no_content("Scheduled duration:")
  end

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

  it "keeps staff action details as text" do
    visit "/admin/logs/staff_action_logs"

    expect(staff_action_logs_page).to have_no_injected_detail_element(history_with_html_value)
    expect(staff_action_logs_page).to have_details_text(
      history_with_html_value,
      %(<img src=x onerror="alert('xss')">),
    )
  end

  it "keeps HTML submitted through self-deletion as context text" do
    attacker = Fabricate(:user, refresh_auto_groups: true)
    payload = %(<img src="https://attacker.invalid/staff-action-log-context">)

    sign_in(attacker)
    visit "/u/#{attacker.username}/preferences/account"

    status = page.evaluate_async_script(<<~JS, "/u/#{attacker.username}.json", payload)
        const [url, context, done] = arguments;
        fetch("/session/csrf.json")
          .then((response) => response.json())
          .then(({ csrf }) =>
            fetch(url, {
              body: JSON.stringify({ context }),
              credentials: "same-origin",
              headers: {
                "Content-Type": "application/json",
                "X-CSRF-Token": csrf,
              },
              method: "DELETE",
            })
          )
          .then((response) => done(response.status));
      JS

    expect(status).to eq(200)

    history = UserHistory.where(action: UserHistory.actions[:delete_user]).last

    sign_in(current_user)
    visit "/admin/logs/staff_action_logs"

    expect(staff_action_logs_page.log_row(history)).to have_no_css(".context img")
    expect(staff_action_logs_page.log_row(history)).to have_css(".context", text: payload)
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
