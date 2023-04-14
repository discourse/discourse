# frozen_string_literal: true

RSpec.describe Admin::EmbeddingController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user) { Fabricate(:user) }

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns embedding" do
        get "/admin/customize/embedding.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body["embedding"]).to be_present
      end
    end

    shared_examples "embedding accessible" do
      it "returns embedding" do
        get "/admin/customize/embedding.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "embedding accessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "embedding accessible"
    end
  end

  describe "#update" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "updates embedding" do
        put "/admin/customize/embedding.json",
            params: {
              embedding: {
                embed_by_username: "system",
                embed_post_limit: 200,
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["embedding"]["embed_by_username"]).to eq("system")
        expect(response.parsed_body["embedding"]["embed_post_limit"]).to eq(200)
      end
    end

    shared_examples "embedding updates not allowed" do
      it "prevents updates with a 404 response" do
        put "/admin/customize/embedding.json",
            params: {
              embedding: {
                embed_by_username: "system",
                embed_post_limit: 200,
              },
            }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(response.parsed_body["embedding"]).to be_nil
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "embedding updates not allowed"
    end

    context "when logged in as a moderator" do
      before { sign_in(user) }

      include_examples "embedding updates not allowed"
    end
  end
end
