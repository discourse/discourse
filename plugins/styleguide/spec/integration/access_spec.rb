# frozen_string_literal: true

RSpec.describe "SiteSetting.styleguide_admin_only" do
  before { SiteSetting.styleguide_enabled = true }

  context "when styleguide is admin only" do
    before { SiteSetting.styleguide_admin_only = true }

    context "when user is admin" do
      before { sign_in(Fabricate(:admin)) }

      it "shows the styleguide" do
        get "/styleguide"
        expect(response.status).to eq(200)
      end
    end

    context "when user is not admin" do
      before { sign_in(Fabricate(:user)) }

      it "doesn’t allow access" do
        get "/styleguide"
        expect(response.status).to eq(403)
      end
    end
  end
end

RSpec.describe "SiteSetting.styleguide_enabled" do
  before { sign_in(Fabricate(:admin)) }

  context "when style is enabled" do
    before { SiteSetting.styleguide_enabled = true }

    it "shows the styleguide" do
      get "/styleguide"
      expect(response.status).to eq(200)
    end
  end

  context "when styleguide is disabled" do
    before { SiteSetting.styleguide_enabled = false }

    it "returns a page not found" do
      get "/styleguide"
      expect(response.status).to eq(404)
    end
  end
end
