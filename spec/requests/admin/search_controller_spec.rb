# frozen_string_literal: true

RSpec.describe Admin::SearchController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "#index" do
    it "includes default_locale setting in search results for general searches" do
      get "/admin/search/all.json"

      expect(response.status).to eq(200)

      locale_setting =
        response.parsed_body["settings"].find { |s| s["setting"] == "default_locale" }

      expect(locale_setting).to be_present
    end
  end
end
