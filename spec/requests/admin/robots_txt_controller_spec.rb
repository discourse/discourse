# frozen_string_literal: true

RSpec.describe Admin::RobotsTxtController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns default content if there are no overrides" do
        get "/admin/customize/robots.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["robots_txt"]).to be_present
        expect(json["overridden"]).to eq(false)
      end

      it "returns overridden content if there are overrides" do
        SiteSetting.overridden_robots_txt = "something"
        get "/admin/customize/robots.json"
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["robots_txt"]).to eq("something")
        expect(json["overridden"]).to eq(true)
      end
    end

    shared_examples "robot.txt inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/customize/robots.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "robot.txt inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "robot.txt inaccessible"
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "overrides the site's default robots.txt" do
        put "/admin/customize/robots.json", params: { robots_txt: "new_content" }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["robots_txt"]).to eq("new_content")
        expect(json["overridden"]).to eq(true)
        expect(SiteSetting.overridden_robots_txt).to eq("new_content")

        get "/robots.txt"
        expect(response.body).to include("new_content")
      end

      it "requires `robots_txt` param to be present" do
        SiteSetting.overridden_robots_txt = "overridden_content"
        put "/admin/customize/robots.json", params: { robots_txt: "" }
        expect(response.status).to eq(400)
      end
    end

    shared_examples "robot.txt update not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/customize/robots.json", params: { robots_txt: "adasdasd" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(SiteSetting.overridden_robots_txt).to eq("")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "robot.txt update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "robot.txt update not allowed"
    end
  end

  describe "#reset" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "resets robots.txt file to the default version" do
        SiteSetting.overridden_robots_txt = "overridden_content"
        SiteSetting.allowed_crawler_user_agents = "test-user-agent-154"

        delete "/admin/customize/robots.json", xhr: true
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["robots_txt"]).not_to include("overridden_content")
        expect(json["robots_txt"]).not_to include("</html>")
        expect(json["robots_txt"]).to include("User-agent: test-user-agent-154\n")
        expect(json["overridden"]).to eq(false)

        expect(SiteSetting.overridden_robots_txt).to eq("")
      end
    end

    shared_examples "robot.txt reset not allowed" do
      it "prevents resets with a 404 response" do
        SiteSetting.overridden_robots_txt = "overridden_content"

        delete "/admin/customize/robots.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(SiteSetting.overridden_robots_txt).to eq("overridden_content")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "robot.txt reset not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "robot.txt reset not allowed"
    end
  end
end
