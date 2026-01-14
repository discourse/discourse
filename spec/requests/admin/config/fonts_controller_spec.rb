# frozen_string_literal: true

RSpec.describe Admin::Config::FontsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  describe "#fonts" do
    context "when logged in as an admin" do
      before { sign_in(admin) }
      it "updates the fonts and text size" do
        put "/admin/config/fonts.json",
            params: {
              base_font: "helvetica",
              heading_font: "roboto",
              default_text_size: "largest",
            }
        expect(response.status).to eq(200)

        expect(SiteSetting.base_font).to eq("helvetica")
        expect(SiteSetting.heading_font).to eq("roboto")
        expect(SiteSetting.default_text_size).to eq("largest")
      end

      it "validates values" do
        put "/admin/config/fonts.json",
            params: {
              base_font: "invalid_font",
              heading_font: "invalid_font",
              default_text_size: "invalid_size",
            }
        expect(response.status).to eq(400)
        expect(SiteSetting.base_font).to eq("inter")
        expect(SiteSetting.heading_font).to eq("inter")
        expect(SiteSetting.default_text_size).to eq("normal")
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }
      it "denies access with a 403 response" do
        put "/admin/config/fonts.json",
            params: {
              base_font: "helvetica",
              heading_font: "roboto",
              default_text_size: "largest",
            }
        expect(response.status).to eq(403)
        expect(SiteSetting.base_font).to eq("inter")
        expect(SiteSetting.heading_font).to eq("inter")
        expect(SiteSetting.default_text_size).to eq("normal")
      end
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      it "denies access with a 404 response" do
        put "/admin/config/fonts.json",
            params: {
              base_font: "helvetica",
              heading_font: "roboto",
              default_text_size: "largest",
            }

        expect(response.status).to eq(404)
        expect(SiteSetting.base_font).to eq("inter")
        expect(SiteSetting.heading_font).to eq("inter")
        expect(SiteSetting.default_text_size).to eq("normal")
      end
    end
  end
end
