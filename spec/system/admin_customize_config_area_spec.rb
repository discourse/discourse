# frozen_string_literal: true

describe "Admin Customize Config Area Page", type: :system do
  fab!(:admin)

  let(:config_area) { PageObjects::Pages::AdminCustomizeConfigArea.new }
  let(:install_modal) { PageObjects::Modals::Base.new }

  before { sign_in(admin) }

  context "when in the themes tab" do
    it "has a special card for installing new themes" do
      config_area.visit

      expect(config_area.install_card).to have_text(
        I18n.t("admin_js.admin.config_areas.themes_and_components.themes.new_theme"),
      )

      config_area.install_card.find(".btn-primary").click
      expect(install_modal).to be_open
    end
  end

  context "when in the components tab" do
    it "has a special card for installing new components" do
      config_area.visit_components

      expect(config_area.install_card).to have_text(
        I18n.t("admin_js.admin.config_areas.themes_and_components.components.new_component"),
      )

      config_area.install_card.find(".btn-primary").click
      expect(install_modal).to be_open
    end
  end
end
