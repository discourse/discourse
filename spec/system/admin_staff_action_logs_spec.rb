# frozen_string_literal: true

describe "Admin staff action logs", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:history_1) do
    Fabricate(
      :site_setting_change_history,
      subject: "enforce_second_factor",
      previous_value: "no",
      new_value: "all",
    )
  end
  fab!(:history_2) { Fabricate(:topic_closed_change_history) }

  before { sign_in(current_user) }

  it "shows details for an action" do
    visit "/admin/logs/staff_action_logs"

expect(find(".staff-logs tr[data-user-history-id='#{history_1.id}']"))
  .to have_content(I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"))
  .and have_content("enforce_second_factor")
  .and have_content(I18n.t("admin_js.admin.logs.staff_actions.new_value", "all"))
  .and have_content(I18n.t("admin_js.admin.logs.staff_actions.previous_value", "no"))

    expect(find(".staff-logs tr[data-user-history-id='#{history_2.id}']")).to have_content(
      I18n.t("admin_js.admin.logs.staff_actions.actions.topic_closed"),
    )
    expect(find(".staff-logs tr[data-user-history-id='#{history_2.id}']")).to have_css(
      "[data-link-topic-id='#{history_2.topic_id}']",
    )
  end

  it "can filter by type of action" do
    visit "/admin/logs/staff_action_logs"

    expect(page).to have_css(".staff-logs tr[data-user-history-id='#{history_1.id}']")
    expect(page).to have_css(".staff-logs tr[data-user-history-id='#{history_2.id}']")

    filter = PageObjects::Components::SelectKit.new("#staff-action-logs-action-filter")
    filter.search(I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"))
    filter.select_row_by_value(
      UserHistory.actions.key(UserHistory.actions[:change_site_setting]).to_s,
    )

    expect(page).to have_css(
      ".staff-action-logs-filters .filter",
      text: I18n.t("admin_js.admin.logs.staff_actions.actions.change_site_setting"),
    )

    expect(page).to have_css(".staff-logs tr[data-user-history-id='#{history_1.id}']")
    expect(page).to have_no_css(".staff-logs tr[data-user-history-id='#{history_2.id}']")
  end

  it "can show details for an action" do
    history_1.update!(
      details:
        "Discourse is automatically enabling this for all our hosted customers, please see https://meta.discourse.org/t/123 for more information.",
    )
    visit "/admin/logs/staff_action_logs"

    find(".staff-logs tr[data-user-history-id='#{history_1.id}'] .col.value.details a").click
    expect(PageObjects::Modals::Base.new).to have_content(history_1.details)
  end
end
