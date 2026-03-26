# frozen_string_literal: true

describe "Discovery Layout" do
  fab!(:topics) { Fabricate.times(5, :post).map(&:topic) }

  context "when discovery_layout_with_sidebar_block is disabled" do
    before { SiteSetting.discovery_layout_with_sidebar_block = false }

    it "does not render the discovery-layout wrapper on /latest" do
      visit("/latest")
      expect(page).to have_css("#list-area")
      expect(page).to have_no_css(".discovery-layout")
      expect(page).to have_no_css(".discovery-layout__sidebar")
    end
  end

  context "when discovery_layout_with_sidebar_block is enabled" do
    before { SiteSetting.discovery_layout_with_sidebar_block = true }

    it "renders the discovery-layout wrapper with sidebar on /latest" do
      visit("/latest")
      expect(page).to have_css(".discovery-layout")
      expect(page).to have_css(".discovery-layout__list #list-area")
      expect(page).to have_css(".discovery-layout__sidebar")
    end
  end
end
