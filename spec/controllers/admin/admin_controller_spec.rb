require 'rails_helper'

describe Admin::AdminController do

  context 'index' do

    it 'needs you to be logged in' do
      get :index, format: :json
      expect(response.status).to eq(403)
    end

    it "raises an error if you aren't an admin" do
      _user = log_in
      get :index, format: :json
      expect(response).to be_forbidden
    end

  end

end
