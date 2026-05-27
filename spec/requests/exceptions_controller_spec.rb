# frozen_string_literal: true

RSpec.describe ExceptionsController do
  describe "#not_found" do
    it "should return the right response" do
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

      it "should return the right response" do
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

      {
        nil => "(prefers-color-scheme: dark)",
        "auto" => "(prefers-color-scheme: dark)",
        "light" => "none",
        "dark" => "all",
      }.each do |cookie, media|
        it "uses media=#{media.inspect} when forced_color_mode is #{cookie.inspect}" do
          cookies[:forced_color_mode] = cookie

          get "/404"

          expect(response.body).to have_tag("source", with: { media: })
        end
      end
    end
  end
end
