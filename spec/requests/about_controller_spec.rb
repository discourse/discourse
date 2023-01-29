# frozen_string_literal: true

RSpec.describe AboutController do
  describe "#index" do
    it "should display the about page for anonymous user when login_required is false" do
      SiteSetting.login_required = false
      get "/about"

      expect(response.status).to eq(200)
      expect(response.body).to include("<title>About - Discourse</title>")
    end

    it "should redirect to login page for anonymous user when login_required is true" do
      SiteSetting.login_required = true
      get "/about"

      expect(response).to redirect_to "/login"
    end

    it "should display the about page for logged in user when login_required is true" do
      SiteSetting.login_required = true
      sign_in(Fabricate(:user))
      get "/about"

      expect(response.status).to eq(200)
    end

    context "with crawler view" do
      it "should include correct title" do
        get "/about", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("<title>About - Discourse</title>")
      end

      it "should include correct user URLs" do
        Fabricate(:admin, username: "anAdminUser")
        get "/about", headers: { "HTTP_USER_AGENT" => "Googlebot" }
        expect(response.status).to eq(200)
        expect(response.body).to include("/u/anadminuser")
      end
    end

    it "serializes stats when 'Guardian#can_see_about_stats?' is true" do
      Guardian.any_instance.stubs(:can_see_about_stats?).returns(true)
      get "/about.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["about"].keys).to include("stats")
    end

    it "does not serialize stats when 'Guardian#can_see_about_stats?' is false" do
      Guardian.any_instance.stubs(:can_see_about_stats?).returns(false)
      get "/about.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["about"].keys).not_to include("stats")
    end
  end
end
