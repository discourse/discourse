require 'rails_helper'

describe WizardController do
  context 'wizard enabled' do
    before do
      SiteSetting.wizard_enabled = true
    end

    it 'needs you to be logged in' do
      get "/wizard.json"
      expect(response.status).to eq(403)
    end

    it 'needs you to be logged in' do
      get "/wizard"
      # for whatever reason, no access is 404
      # we may want to revisit this at some point and make it 403
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      sign_in(Fabricate(:moderator))
      get "/wizard.json"
      expect(response).to be_forbidden
    end

    it "raises an error if the wizard is disabled" do
      SiteSetting.wizard_enabled = false
      sign_in(Fabricate(:admin))
      get "/wizard.json"
      expect(response).to be_forbidden
    end

    it "renders the wizard if you are an admin" do
      sign_in(Fabricate(:admin))
      get "/wizard.json"
      expect(response.status).to eq(200)
    end

    it "returns JSON when the mime type is appropriate" do
      sign_in(Fabricate(:admin))
      get "/wizard.json"
      expect(response.status).to eq(200)
      expect(::JSON.parse(response.body).has_key?('wizard')).to eq(true)
    end
  end
end
