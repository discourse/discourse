# frozen_string_literal: true

RSpec.describe Jepsen::ExamplesController do
  describe "#index" do
    it "serves the example JSON to anonymous visitors by default" do
      expect(SiteSetting.jepsen_enabled).to eq(true)

      get "/jepsen/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "serves the example JSON to signed-in users" do
      sign_in(Fabricate(:user))

      get "/jepsen/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "returns a 404 when the plugin is disabled" do
      SiteSetting.jepsen_enabled = false

      get "/jepsen/examples.json"

      expect(response.status).to eq(404)
    end

    it "requires authentication on login-required sites" do
      SiteSetting.login_required = true

      get "/jepsen/examples.json"

      expect(response.status).to eq(403)
    end
  end
end
