require 'rails_helper'

describe Wizard::WizardController do

  context 'index' do
    render_views

    it 'needs you to be logged in' do
      expect { xhr :get, :index }.to raise_error(Discourse::NotLoggedIn)
    end

    it "raises an error if you aren't an admin" do
      log_in
      xhr :get, :index
      expect(response).to be_forbidden
    end

    it "renders the wizard if you are an admin" do
      log_in(:admin)
      xhr :get, :index
      expect(response).to be_success
    end
  end

end
