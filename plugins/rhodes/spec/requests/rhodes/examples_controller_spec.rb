# frozen_string_literal: true

RSpec.describe Rhodes::ExamplesController do
  describe "#index" do
    it "returns the example response for anonymous visitors by default" do
      get "/rhodes/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "returns the example response for signed-in users" do
      sign_in(Fabricate(:user))

      get "/rhodes/examples.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("hello" => "world")
    end

    it "returns a 404 when Rhodes is disabled" do
      SiteSetting.rhodes_enabled = false

      get "/rhodes/examples.json"

      expect(response.status).to eq(404)
    end

    it "requires authentication when the site requires login" do
      SiteSetting.login_required = true

      get "/rhodes/examples.json"

      expect(response.status).to eq(403)
    end
  end
end
