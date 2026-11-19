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
    expect(badge_row).to have_css("[data-badge-name='#{badge.name}']")

    badge_row.click_link(granter.username)
    expect(page).to have_current_path "/admin/users/#{granter.id}/#{granter.username}"
  end

  shared_examples "granting from the badge list" do
    it "shows badges with SQL queries in the grant dropdown" do
      badge_with_query =
        Fabricate(
          :badge,
          name: "SQL Badge",
          query: "SELECT user_id, current_timestamp granted_at FROM users WHERE false",
        )

      user_badges_page.visit_page(user)

      expect(user_badges_page).to have_grantable_badge(badge_with_query.name)
    end

    it "grants the picked badge" do
      user_badges_page.visit_page(user).grant_badge(badge.name)

      expect(user_badges_page.find_badge_row_by_granter(granter)).to have_css(
        "[data-badge-name='#{badge.name}']",
      )
      expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
    end
  end

  include_examples "granting from the badge list"

  context "with the new select controls" do
    with_select_controls(true)

    include_examples "granting from the badge list"
  end
end
