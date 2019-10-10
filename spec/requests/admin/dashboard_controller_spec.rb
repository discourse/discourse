# frozen_string_literal: true

require 'rails_helper'

describe Admin::DashboardController do
  before do
    AdminDashboardData.stubs(:fetch_cached_stats).returns(reports: [])
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
  end

  it "is a subclass of AdminController" do
    expect(Admin::DashboardController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    fab!(:admin) { Fabricate(:admin) }

    before do
      sign_in(admin)
    end

    describe '#index' do
      context 'version checking is enabled' do
        before do
          SiteSetting.version_checks = true
        end

        it 'returns discourse version info' do
          get "/admin/dashboard.json"

          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['version_check']).to be_present
        end
      end

      context 'version checking is disabled' do
        before do
          SiteSetting.version_checks = false
        end

        it 'does not return discourse version info' do
          get "/admin/dashboard.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json['version_check']).not_to be_present
        end
      end
    end

    describe '#problems' do
      context 'when there are no problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns([])
        end

        it 'returns an empty array' do
          get "/admin/dashboard/problems.json"

          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json['problems'].size).to eq(0)
        end
      end

      context 'when there are problems' do
        before do
          AdminDashboardData.stubs(:fetch_problems).returns(['Not enough awesome', 'Too much sass'])
        end

        it 'returns an array of strings' do
          get "/admin/dashboard/problems.json"
          expect(response.status).to eq(200)
          json = JSON.parse(response.body)
          expect(json['problems'].size).to eq(2)
          expect(json['problems'][0]).to be_a(String)
          expect(json['problems'][1]).to be_a(String)
        end
      end
    end
  end
end
