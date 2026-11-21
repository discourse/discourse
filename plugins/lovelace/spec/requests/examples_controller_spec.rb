# frozen_string_literal: true

RSpec.describe Lovelace::ExamplesController do
  before { enable_current_plugin }

  describe "#index" do
    it "returns the example response for a signed-in user" do
      sign_in(Fabricate(:user))

      get "/lovelace/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "allows anonymous requests on a public site" do
      get "/lovelace/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "requires login on a private site" do
      SiteSetting.login_required = true

      get "/lovelace/examples.json"

      expect(response.status).to eq(403)
    end

    it "returns not found when the plugin is disabled" do
      sign_in(Fabricate(:user))
      SiteSetting.lovelace_enabled = false

      get "/lovelace/examples.json"

      expect(response.status).to eq(404)
    end
  end
end
