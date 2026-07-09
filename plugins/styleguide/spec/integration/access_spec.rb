# frozen_string_literal: true

RSpec.describe "SiteSetting.styleguide_allowed_groups" do
  before { SiteSetting.styleguide_enabled = true }

  context "when styleguide is admin only" do
    before { SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:admins] }

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
        expect(response.status).to eq(404)
      end
    end
  end

  context "when user is anonymous" do
    context "when styleguide_allowed_groups is set to everyone" do
      before { SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:everyone] }

      it "does not show the styleguide" do
        get "/styleguide"
        expect(response.status).to eq(404)
      end

      context "when styleguide_allowed_groups includes anonymous_users" do
        before { SiteSetting.styleguide_allowed_groups = "#{Group::AUTO_GROUPS[:anonymous_users]}" }

        it "shows the styleguide" do
          get "/styleguide"
          expect(response.status).to eq(200)
        end
      end

      context "when granular_anonymous_and_logged_in_groups_permissions is not enabled" do
        before { SiteSetting.granular_anonymous_and_logged_in_groups_permissions = false }

        it "shows the styleguide" do
          get "/styleguide"
          expect(response.status).to eq(200)
        end
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
