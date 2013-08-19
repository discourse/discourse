require 'spec_helper'

describe Admin::SiteSettingsController do

  it "is a subclass of AdminController" do
    (Admin::SiteSettingsController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    context 'index' do
      it 'returns success' do
        xhr :get, :index
        response.should be_success
      end

      it 'returns JSON' do
        xhr :get, :index
        ::JSON.parse(response.body).should be_present
      end
    end

    context 'update' do

      it 'requires a value parameter' do
        lambda { xhr :put, :update, id: 'test_setting' }.should raise_error(ActionController::ParameterMissing)
      end

      it 'sets the value when the param is present' do
        SiteSetting.expects(:'test_setting=').with('hello').once
        xhr :put, :update, id: 'test_setting', value: 'hello'
      end

      it 'allows value to be a blank string' do
        SiteSetting.expects(:'test_setting=').with('').once
        xhr :put, :update, id: 'test_setting', value: ''
      end

      it 'logs the change' do
        SiteSetting.stubs(:test_setting).returns('previous')
        SiteSetting.expects(:'test_setting=').with('hello').once
        StaffActionLogger.any_instance.expects(:log_site_setting_change).with('test_setting', 'previous', 'hello')
        xhr :put, :update, id: 'test_setting', value: 'hello'
      end
    end

  end



end
