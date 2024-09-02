# frozen_string_literal: true

describe "Admin Badges Grouping Modal", type: :system do
  before { SiteSetting.enable_badges = true }

  fab!(:current_user) { Fabricate(:admin) }

  let(:badges_page) { PageObjects::Pages::AdminBadges.new }
  let(:badges_groupings_page) { PageObjects::Pages::AdminBadgesGroupings.new }

  before { sign_in(current_user) }

  context "when adding a new grouping" do
    it "saves it" do
      badges_page.visit_page(Badge::Autobiographer).edit_groupings
      badges_groupings_page.add_grouping("a new grouping")

      try_until_success { BadgeGrouping.exists?(name: "a new grouping") }
    end
  end
end
