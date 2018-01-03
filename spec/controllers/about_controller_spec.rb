require 'rails_helper'

describe AboutController do

  context '.index' do

    it "should display the about page for anonymous user when login_required is false" do
      SiteSetting.login_required = false
      get :index

      expect(response).to be_success
    end

    it 'should redirect to login page for anonymous user when login_required is true' do
      SiteSetting.login_required = true
      get :index

      expect(response).to redirect_to '/login'
    end

    it "should display the about page for logged in user when login_required is true" do
      SiteSetting.login_required = true
      log_in
      get :index

      expect(response).to be_success
    end
  end
end
