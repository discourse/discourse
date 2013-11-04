require 'spec_helper'
require_dependency 'version'

describe Admin::VersionsController do

  before do
    Jobs::VersionCheck.any_instance.stubs(:execute).returns(true)
    DiscourseUpdates.stubs(:updated_at).returns(2.hours.ago)
    DiscourseUpdates.stubs(:latest_version).returns('1.2.33')
    DiscourseUpdates.stubs(:critical_updates_available?).returns(false)
  end

  it "is a subclass of AdminController" do
    (Admin::VersionsController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    describe 'show' do
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
  end
end