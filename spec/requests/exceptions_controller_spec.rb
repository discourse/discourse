require 'rails_helper'

RSpec.describe ExceptionsController do
  describe "#not_found" do
    it "should return the right response" do
      get "/404"

      expect(response.status).to eq(404)

      expect(response.body).to have_tag(
        "img",
        with: {
          src: SiteSetting.site_home_logo_url
        }
      )
    end

    describe "text site logo" do
      let(:title) { "some awesome title" }

      before do
        SiteSetting.title = title
      end

      it "should return the right response" do
        get "/404"

        expect(response.status).to eq(404)

        expect(response.body).to have_tag(
          "h2",
          text: title
        )
      end
    end
  end
end
