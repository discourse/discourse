# frozen_string_literal: true

RSpec.describe Hamilton::ExamplesController do
  before { enable_current_plugin }

  describe "#index" do
    it "returns the example response on a public site" do
      get "/hamilton/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "returns 404 when Hamilton is disabled" do
      SiteSetting.hamilton_enabled = false

      get "/hamilton/examples.json"

      expect(response.status).to eq(404)
    end

    it "requires authentication when login is required" do
      SiteSetting.login_required = true

      get "/hamilton/examples.json"

      expect(response.status).to eq(403)

      sign_in(Fabricate(:user))
      get "/hamilton/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end
  end
end
