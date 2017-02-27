require 'rails_helper'

describe ExtraLocalesController do

  context 'show' do

    it "needs a valid bundle" do
      get :show, bundle: 'made-up-bundle'
      expect(response).to_not be_success
      expect(response.body).to be_blank
    end

    it "won't work with a weird parameter" do
      get :show, bundle: '-invalid..character!!'
      expect(response).to_not be_success
    end

    it "includes plugin translations" do
      I18n.locale = :en
      I18n.reload!

      JsLocaleHelper.expects(:plugin_translations)
                    .with(I18n.locale.to_s)
                    .returns({
                      "admin_js" => {
                        "admin" => {
                          "site_settings" => {
                            "categories" => {
                              "github_badges" => "Github Badges"
                            }
                          }
                        }
                      }
                    }).at_least_once

      get :show, bundle: "admin"

      expect(response).to be_success
      expect(response.body.include?("github_badges")).to eq(true)
    end

  end

end
