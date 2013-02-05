require 'spec_helper'
require_dependency 'version'

describe Admin::VersionsController do

  before do
    RestClient.stubs(:get).returns( {success: 'OK', version: '1.2.33'}.to_json )
  end

  it "is a subclass of AdminController" do
    (Admin::VersionsController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    describe 'show' do
      context 'when discourse_org_access_key is set' do
        before do
          SiteSetting.stubs(:discourse_org_access_key).returns('asdf')
        end

        subject { xhr :get, :show }
        it { should be_success }

        it 'should return the currently available version' do
          json = JSON.parse(subject.body)
          json['latest_version'].should == '1.2.33'
        end

        it "should return the installed version" do
          json = JSON.parse(subject.body)
          json['installed_version'].should == Discourse::VERSION::STRING
        end
      end

      context 'when discourse_org_access_key is blank' do
        subject { xhr :get, :show }
        it { should be_success }

        it 'should return the installed version as the currently available version' do
          json = JSON.parse(subject.body)
          json['latest_version'].should == Discourse::VERSION::STRING
        end

        it "should return the installed version" do
          json = JSON.parse(subject.body)
          json['installed_version'].should == Discourse::VERSION::STRING
        end
      end
    end
  end
end