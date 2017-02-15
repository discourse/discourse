require 'rails_helper'

describe WizardController do

  context 'wizard enabled' do
    render_views

    before do
      SiteSetting.wizard_enabled = true
    end

    it 'needs you to be logged in' do
      expect { xhr :get, :index }.to raise_error(Discourse::NotLoggedIn)
    end

    it "raises an error if you aren't an admin" do
      log_in(:moderator)
      xhr :get, :index
      expect(response).to be_forbidden
    end

    it "raises an error if the wizard is disabled" do
      SiteSetting.wizard_enabled = false
      log_in(:admin)
      xhr :get, :index
      expect(response).to be_forbidden
    end

    it "renders the wizard if you are an admin" do
      log_in(:admin)
      xhr :get, :index
      expect(response).to be_success
    end

    it "returns JSON when the mime type is appropriate" do
      log_in(:admin)
      xhr :get, :index, format: 'json'
      expect(response).to be_success
      expect(::JSON.parse(response.body).has_key?('wizard')).to eq(true)
    end
  end

end
