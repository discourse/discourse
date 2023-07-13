# frozen_string_literal: true

RSpec.describe SafeModeController do
  describe "index" do
    it "never includes customizations" do
      theme = Fabricate(:theme)
      theme.set_field(target: :common, name: "header", value: "My Custom Header")
      theme.save!
      theme.set_default!

      Fabricate(:admin) # Avoid wizard page

      get "/"

      expect(response.status).to eq(200)
      expect(response.body).to include("data-theme-id=\"#{theme.id}\"")

      get "/safe-mode"

      expect(response.status).to eq(200)
      expect(response.body).not_to include("My Custom Header")
      expect(response.body).not_to include("data-theme-id=\"#{theme.id}\"")
    end
  end

  describe "enter" do
    context "when no params are given" do
      it "should redirect back to safe mode page" do
        post "/safe-mode"
        expect(response.status).to redirect_to(safe_mode_path)
      end
    end

    context "when safe mode is not enabled" do
      it "should raise an error" do
        SiteSetting.enable_safe_mode = false
        post "/safe-mode"
        expect(response.status).to eq(404)
      end

      it "doesn't raise an error for staff" do
        SiteSetting.enable_safe_mode = false
        sign_in(Fabricate(:moderator))
        post "/safe-mode"
        expect(response.status).to redirect_to(safe_mode_path)
      end
    end
  end
end
