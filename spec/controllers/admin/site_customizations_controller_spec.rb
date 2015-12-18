require 'rails_helper'

describe Admin::SiteCustomizationsController do

  it "is a subclass of AdminController" do
    expect(Admin::UsersController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context ' .index' do
      it 'returns success' do
        SiteCustomization.create!(name: 'my name', user_id: Fabricate(:user).id, header: "my awesome header", stylesheet: "my awesome css")
        xhr :get, :index
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context ' .create' do
      it 'returns success' do
        xhr :post, :create, site_customization: {name: 'my test name'}
        expect(response).to be_success
      end

      it 'returns json' do
        xhr :post, :create, site_customization: {name: 'my test name'}
        expect(::JSON.parse(response.body)).to be_present
      end

      it 'logs the change' do
        StaffActionLogger.any_instance.expects(:log_site_customization_change).once
        xhr :post, :create, site_customization: {name: 'my test name'}
      end
    end

  end



end
