require 'rails_helper'

describe Admin::SiteSettingsController do

  it "is a subclass of AdminController" do
    expect(Admin::SiteSettingsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context 'index' do
      it 'returns success' do
        xhr :get, :index
        expect(response).to be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        expect(::JSON.parse(response.body)).to be_present
      end
    end

    context 'update' do

      before do
        SiteSetting.setting(:test_setting, "default")
      end

      it 'sets the value when the param is present' do
        SiteSetting.expects(:'test_setting=').with('hello').once
        xhr :put, :update, id: 'test_setting', test_setting: 'hello'
      end

      it 'allows value to be a blank string' do
        SiteSetting.expects(:'test_setting=').with('').once
        xhr :put, :update, id: 'test_setting', test_setting: ''
      end

      it 'logs the change' do
        SiteSetting.stubs(:test_setting).returns('previous')
        SiteSetting.expects(:'test_setting=').with('hello').once
        StaffActionLogger.any_instance.expects(:log_site_setting_change).with('test_setting', 'previous', 'hello')
        xhr :put, :update, id: 'test_setting', test_setting: 'hello'
      end

      it 'fails when a setting does not exist' do
        expect {
          xhr :put, :update, id: 'provider', provider: 'gotcha'
        }.to raise_error(ArgumentError)
      end
    end

  end

end
