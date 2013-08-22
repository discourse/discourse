require 'spec_helper'

describe Admin::SiteCustomizationsController do

  it "is a subclass of AdminController" do
    (Admin::UsersController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context ' .index' do
      it 'returns success' do
        SiteCustomization.create!(name: 'my name', user_id: Fabricate(:user).id, header: "my awesome header", stylesheet: "my awesome css")
        xhr :get, :index
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        ::JSON.parse(response.body).should be_present
      end
    end

    context ' .create' do
      it 'returns success' do
        xhr :post, :create, site_customization: {name: 'my test name'}
        response.should be_success
      end

      it 'returns json' do
        xhr :post, :create, site_customization: {name: 'my test name'}
        ::JSON.parse(response.body).should be_present
      end

      it 'logs the change' do
        StaffActionLogger.any_instance.expects(:log_site_customization_change).once
        xhr :post, :create, site_customization: {name: 'my test name'}
      end
    end

  end



end
