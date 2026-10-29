# frozen_string_literal: true

RSpec.describe ExceptionsController do
  describe "#not_found" do
    it "renders the not-found page" do
      get "/404"

      expect(response.status).to eq(404)

      expect(response.body).to have_tag(
        "title",
        text: "#{I18n.t("page_not_found.page_title")} - #{SiteSetting.title}",
      )

      expect(response.body).to have_tag("img", with: { src: SiteSetting.site_logo_url })
    end

    describe "text site logo" do
      before { SiteSetting.logo = "" }

      it "renders the not-found page with the text logo" do
        get "/404"

        expect(response.status).to eq(404)

        expect(response.body).to have_tag("h2", text: SiteSetting.title)
      end
    end

    describe "logo dark mode media query" do
      fab!(:upload_light, :upload)
      fab!(:upload_dark, :upload)

      let(:light_scheme_id) { ColorScheme::NAMES_TO_ID_MAP["Solarized Light"] }
      let(:dark_scheme_id) { ColorScheme::NAMES_TO_ID_MAP["Dark"] }

      before do
        SiteSetting.logo = upload_light
        SiteSetting.logo_dark = upload_dark
        SiteSetting.interface_color_selector = "sidebar_footer"

        color_scheme_id = ColorScheme.where(base_scheme_id: light_scheme_id).pick(:id)
        dark_color_scheme_id = ColorScheme.where(base_scheme_id: dark_scheme_id).pick(:id)

        Theme.find_default.update!(color_scheme_id:, dark_color_scheme_id:)
      end

      it "uses media=\"(prefers-color-scheme: dark)\" when forced_color_mode is nil" do
        cookies[:forced_color_mode] = nil

        get "/404"

        expect(response.body).to have_tag("source", with: { media: "(prefers-color-scheme: dark)" })
      end

      it "uses media=\"(prefers-color-scheme: dark)\" when forced_color_mode is \"auto\"" do
        cookies[:forced_color_mode] = "auto"

        get "/404"

        expect(response.body).to have_tag("source", with: { media: "(prefers-color-scheme: dark)" })
      end

      it "uses media=\"none\" when forced_color_mode is \"light\"" do
        cookies[:forced_color_mode] = "light"

        get "/404"

        expect(response.body).to have_tag("source", with: { media: "none" })
      end

      it "uses media=\"all\" when forced_color_mode is \"dark\"" do
        cookies[:forced_color_mode] = "dark"

        get "/404"

        expect(response.body).to have_tag("source", with: { media: "all" })
      end
    end
  end
end
