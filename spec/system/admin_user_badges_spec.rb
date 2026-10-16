# frozen_string_literal: true

describe "Admin User Badges Page" do
  before { SiteSetting.enable_badges = true }

  fab!(:granter, :admin)
  fab!(:user)
  fab!(:badge, :manually_grantable_badge)
  let(:user_badges_page) { PageObjects::Pages::AdminUserBadges.new }

  before { sign_in(granter) }

  it "displays badge granter and links to their profile" do
    BadgeGranter.grant(badge, user, granted_by: granter)
    badge_row = user_badges_page.visit_page(user).find_badge_row_by_granter(granter)
    expect(
      badge_row.locator("[data-badge-name='#{badge.name}']").filter(visible: true),
    ).not_to have_count(0)

    badge_row
      .locator("[id=#{granter.username.to_s.to_json}], [name=#{granter.username.to_s.to_json}]")
      .or(badge_row.get_by_role("link", name: granter.username))
      .filter(visible: true)
      .click
    expect(browser_page).to have_url("/admin/users/#{granter.id}/#{granter.username}")
  end

  it "shows badges with SQL queries in the grant dropdown" do
    badge_with_query =
      Fabricate(
        :badge,
        name: "SQL Badge",
        query: "SELECT user_id, current_timestamp granted_at FROM users WHERE false",
      )

    user_badges_page.visit_page(user)

    badge_dropdown = PageObjects::Components::SelectKit.new(".user-badges .combo-box")
    badge_dropdown.expand

    expect(
      browser_root.locator(".select-kit-row[data-name='#{badge_with_query.name}']").filter(
        visible: true,
      ),
    ).not_to have_count(0)
  end
end
