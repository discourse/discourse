require 'rails_helper'
require_dependency 'discourse_version_check'

describe Admin::DashboardController do
  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns({reports:[]})
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
  end

  it "is a subclass of AdminController" do
    expect(Admin::DashboardController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    let!(:admin) { log_in(:admin) }

    context '.index' do
      it 'should be successful' do
        xhr :get, :index
        expect(response).to be_successful
      end

      context 'version checking is enabled' do
        before do
          SiteSetting.stubs(:version_checks).returns(true)
        end

        it 'returns discourse version info' do
          xhr :get, :index
          json = JSON.parse(response.body)
          expect(json['version_check']).to be_present
        end
      end

      context 'version checking is disabled' do
        before do
          SiteSetting.stubs(:version_checks).returns(false)
        end

        it 'does not return discourse version info' do
          xhr :get, :index
          json = JSON.parse(response.body)
          expect(json['version_check']).not_to be_present
        end
      end
    end

    context '.problems' do
      it 'should be successful' do
        AdminDashboardData.stubs(:fetch_problems).returns([])
        xhr :get, :problems
        expect(response).to be_successful
      end

      context 'when there are no problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns([])
        end

        it 'returns an empty array' do
          xhr :get, :problems
          json = JSON.parse(response.body)
          expect(json['problems'].size).to eq(0)
        end
      end

      context 'when there are problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns(['Not enough awesome', 'Too much sass'])
        end

        it 'returns an array of strings' do
          xhr :get, :problems
          json = JSON.parse(response.body)
          expect(json['problems'].size).to eq(2)
          expect(json['problems'][0]).to be_a(String)
          expect(json['problems'][1]).to be_a(String)
        end
      end
    end
  end
end
