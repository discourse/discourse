# frozen_string_literal: true

describe "Admin Dashboard Redesign | Engagement section" do
  fab!(:current_user, :admin)
  fab!(:moderator)

  fab!(:category_alpha) { Fabricate(:category, name: "Category Alpha") }
  fab!(:category_bravo) { Fabricate(:category, name: "Category Bravo") }
  fab!(:category_dormant) { Fabricate(:category, name: "Category Dormant") }

  let(:dashboard) { PageObjects::Pages::AdminDashboard.new }
  let(:engagement) { dashboard.engagement }

  before do
    SiteSetting.dashboard_improvements = true
    AdminDashboardSectionConfiguration.update(
      [
        { id: "engagement", visible: true },
        { id: "highlights", visible: false },
        { id: "reports", visible: false },
        { id: "traffic", visible: false },
        { id: "search", visible: false },
      ],
      actor: current_user,
    )
    Fabricate(:topic, category: category_alpha, created_at: "2026-06-12")
    Fabricate(:topic, category: category_bravo, created_at: "2026-06-12")
    sign_in(current_user)
  end

  it "persists an admin's 'Activity by category' selection per-site across a refresh",
     time: Time.zone.local(2026, 6, 15, 12, 0, 0) do
    dashboard.visit
    expect(dashboard).to have_section("engagement")
    expect(engagement).to have_activity_row(category_alpha)

    engagement.deselect_activity_category(category_alpha)

    expect(engagement).to have_no_activity_row(category_alpha)
    expect(engagement).to have_activity_row(category_bravo)

    dashboard.visit

    expect(engagement).to have_activity_row(category_bravo)
    expect(engagement).to have_no_activity_row(category_alpha)
  end

  it "does not persist a moderator's 'Activity by category' selection",
     time: Time.zone.local(2026, 6, 15, 12, 0, 0) do
    sign_in(moderator)

    dashboard.visit
    expect(engagement).to have_activity_row(category_alpha)

    engagement.deselect_activity_category(category_alpha)

    expect(engagement).to have_no_activity_row(category_alpha)

    dashboard.visit

    expect(engagement).to have_activity_row(category_alpha)
    expect(engagement).to have_activity_row(category_bravo)
  end

  it "keeps a persisted category selected even when it has no activity in the period",
     time: Time.zone.local(2026, 6, 15, 12, 0, 0) do
    AdminDashboardSectionConfiguration.update_setting(
      section_id: "engagement",
      key: "activity_by_category",
      attrs: {
        category_ids: [category_alpha.id, category_dormant.id],
      },
    )

    dashboard.visit
    expect(dashboard).to have_section("engagement")

    expect(engagement).to have_activity_row(category_alpha)
    expect(engagement).to have_no_activity_row(category_dormant)

    engagement.expand_activity_category_filter

    expect(engagement).to have_selected_activity_category(category_alpha)
    expect(engagement).to have_selected_activity_category(category_dormant)
  end

  it "saves an admin's 'Who's posting' selection when the picker closes, and persists it across a refresh",
     time: Time.zone.local(2026, 6, 15, 12, 0, 0) do
    dashboard.visit
    expect(dashboard).to have_section("engagement")

    engagement.select_whos_posting_category(category_alpha)
    engagement.close_whos_posting_category_filter

    engagement.expand_whos_posting_category_filter
    expect(engagement).to have_selected_whos_posting_category(category_alpha)

    dashboard.visit

    engagement.expand_whos_posting_category_filter
    expect(engagement).to have_selected_whos_posting_category(category_alpha)
  end

  it "does not persist a moderator's 'Who's posting' selection",
     time: Time.zone.local(2026, 6, 15, 12, 0, 0) do
    sign_in(moderator)

    dashboard.visit
    engagement.select_whos_posting_category(category_alpha)
    engagement.close_whos_posting_category_filter

    dashboard.visit
    engagement.expand_whos_posting_category_filter

    expect(engagement).to have_no_selected_whos_posting_category(category_alpha)
  end
end
