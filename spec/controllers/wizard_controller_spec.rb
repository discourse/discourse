require 'rails_helper'

describe WizardController do

  context 'wizard enabled' do
    render_views

    before do
      SiteSetting.wizard_enabled = true
    end

    it 'needs you to be logged in' do
      get :index, format: :json
      expect(response.status).to eq(403)
    end

    it 'needs you to be logged in' do
      get :index
      # for whatever reason, no access is 404
      # we may want to revisit this at some point and make it 403
      expect(response.status).to eq(404)
    end

    it "raises an error if you aren't an admin" do
      log_in(:moderator)
      get :index, format: :json
      expect(response).to be_forbidden
    end

    it "raises an error if the wizard is disabled" do
      SiteSetting.wizard_enabled = false
      log_in(:admin)
      get :index, format: :json
      expect(response).to be_forbidden
    end

    it "renders the wizard if you are an admin" do
      log_in(:admin)
      get :index, format: :json
      expect(response).to be_success
    end

    it "returns JSON when the mime type is appropriate" do
      log_in(:admin)
      get :index, format: 'json'
      expect(response).to be_success
      expect(::JSON.parse(response.body).has_key?('wizard')).to eq(true)
    end
  end

end
