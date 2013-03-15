require 'spec_helper'

describe Admin::DashboardController do

  it "is a subclass of AdminController" do
    (Admin::DashboardController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    let!(:admin) { log_in(:admin) }

    context '.index' do
      it 'should be successful' do
        xhr :get, :index
        response.should be_successful
      end

      context 'version checking is enabled' do
        before do
          SiteSetting.stubs(:version_checks).returns(true)
        end

        it 'returns discourse version info' do
          xhr :get, :index
          json = JSON.parse(response.body)
          json['version_check'].should be_present
        end
      end

      context 'version checking is disabled' do
        before do
          SiteSetting.stubs(:version_checks).returns(false)
        end

        it 'does not return discourse version info' do
          xhr :get, :index
          json = JSON.parse(response.body)
          json['version_check'].should_not be_present
        end
      end

      it 'returns report data' do
        xhr :get, :index
        json = JSON.parse(response.body)
        json.should have_key('reports')
        json['reports'].should be_a(Array)
      end
    end
  end
end