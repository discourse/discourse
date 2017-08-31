require 'rails_helper'

describe Admin::AdminController do

  context 'index' do

    it 'needs you to be logged in' do
      expect do
        get :index, format: :json
      end.to raise_error(Discourse::NotLoggedIn)
    end

    it "raises an error if you aren't an admin" do
      user = log_in
      get :index, format: :json
      expect(response).to be_forbidden
    end

  end

end
