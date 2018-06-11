require 'rails_helper'
require_dependency 'version'

describe Admin::VersionsController do

  before do
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
    DiscourseUpdates.stubs(:updated_at).returns(2.hours.ago)
    DiscourseUpdates.stubs(:latest_version).returns('1.2.33')
    DiscourseUpdates.stubs(:critical_updates_available?).returns(false)
  end

  it "is a subclass of AdminController" do
    expect(Admin::VersionsController < Admin::AdminController).to eq(true)
  end

  context 'while logged in as an admin' do
    let(:admin) { Fabricate(:admin) }
    before do
      sign_in(admin)
    end

    describe 'show' do
      it 'should return the currently available version' do
        get "/admin/version_check.json"
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json['latest_version']).to eq('1.2.33')
      end

      it "should return the installed version" do
        get "/admin/version_check.json"
        json = JSON.parse(response.body)
        expect(response.status).to eq(200)
        expect(json['installed_version']).to eq(Discourse::VERSION::STRING)
      end
    end
  end
end
