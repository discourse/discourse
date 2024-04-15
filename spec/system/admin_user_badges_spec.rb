# frozen_string_literal: true

describe "Admin User Badges Page", type: :system do
  before { SiteSetting.enable_badges = true }

  fab!(:granter) { Fabricate(:admin) }
  fab!(:user)
  fab!(:badge) { Fabricate(:manually_grantable_badge) }
  let(:user_badges_page) { PageObjects::Pages::AdminUserBadges.new }

  before { sign_in(granter) }

  it "displays badge granter and links to their profile" do
    BadgeGranter.grant(badge, user, granted_by: granter)
    badge_row = user_badges_page.visit_page(user).find_badge_row_by_granter(granter)
    expect(badge_row).to have_css("[data-badge-name='#{badge.name}']")

    badge_row.click_link(granter.username)
    expect(page).to have_current_path "/admin/users/#{granter.id}/#{granter.username}"
  end
end
