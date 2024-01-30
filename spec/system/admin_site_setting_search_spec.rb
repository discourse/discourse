# frozen_string_literal: true

describe "Admin Site Setting Search", type: :system do
  let(:settings_page) { PageObjects::Pages::AdminSettings.new }
  fab!(:admin)

  before do
    SiteSetting.title = "Discourse"
    sign_in(admin)
  end

  describe "when searching for keywords" do
    it "finds the associated site setting" do
      settings_page.visit
      settings_page.type_in_search("anonymous_posting_min_trust_level")
      expect(settings_page).to have_search_result("anonymous_posting_allowed_groups")
    end

    it "can search for previous site setting without underscores" do
      settings_page.visit
      settings_page.type_in_search("anonymous posting min")
      expect(settings_page).to have_search_result("anonymous_posting_allowed_groups")
    end
  end
end
