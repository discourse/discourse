# frozen_string_literal: true

RSpec.describe Admin::LlmsTxtController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns empty content if there is no llms.txt configured" do
        get "/admin/customize/llms.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["llms_txt"]).to eq("")
      end

      it "returns content if llms.txt is configured" do
        SiteSetting.llms_txt_content = "# My Site"
        get "/admin/customize/llms.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["llms_txt"]).to eq("# My Site")
      end
    end

    shared_examples "llms.txt inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/customize/llms.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "llms.txt inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "llms.txt inaccessible"
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "saves the llms.txt content" do
        put "/admin/customize/llms.json", params: { llms_txt: "# New Content" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["llms_txt"]).to eq("# New Content")
        expect(SiteSetting.llms_txt_content).to eq("# New Content")

        get "/llms.txt"
        expect(response.body).to eq("# New Content")
      end

      it "requires `llms_txt` param to be present" do
        put "/admin/customize/llms.json", params: {}
        expect(response.status).to eq(400)
      end
    end

    shared_examples "llms.txt update not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/customize/llms.json", params: { llms_txt: "# Content" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(SiteSetting.llms_txt_content).to eq("")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "llms.txt update not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "llms.txt update not allowed"
    end
  end

  describe "#reset" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "resets llms.txt to empty" do
        SiteSetting.llms_txt_content = "# Some Content"

        delete "/admin/customize/llms.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["llms_txt"]).to eq("")
        expect(SiteSetting.llms_txt_content).to eq("")
      end
    end

    shared_examples "llms.txt reset not allowed" do
      it "prevents resets with a 404 response" do
        SiteSetting.llms_txt_content = "# Some Content"

        delete "/admin/customize/llms.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(SiteSetting.llms_txt_content).to eq("# Some Content")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "llms.txt reset not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "llms.txt reset not allowed"
    end
  end
end
