# frozen_string_literal: true

describe "Admin House Ad", type: :system do
  fab!(:admin)
  let(:house_ad) do
    AdPlugin::HouseAd.create(
      name: "some-name",
      html: "<div>somecode</div>",
      visible_to_anons: true,
      visible_to_logged_in_users: false,
    )
  end

  before { sign_in(admin) }

  describe "when visiting the page for creating new ads" do
    it "has the visibility checkboxes on by default" do
      visit("/admin/plugins/pluginad/house_creatives/new")

      expect(find("input.visible-to-anonymous-checkbox").checked?).to eq(true)
      expect(find("input.visible-to-logged-in-checkbox").checked?).to eq(true)
    end
  end

  describe "when visiting the page of an existing ad" do
    it "the controls reflect the correct state of the ad" do
      visit("/admin/plugins/pluginad/house_creatives/#{house_ad.id}")

      expect(find("input.house-ad-name").value).to eq(house_ad.name)
      expect(find("input.visible-to-anonymous-checkbox").checked?).to eq(true)
      expect(find("input.visible-to-logged-in-checkbox").checked?).to eq(false)
      # would be nice to assert for the HTML content in ace-editor, but there
      # doesn't seem to be a way to check the content in ace-editor from the
      # DOM
    end
  end
end
