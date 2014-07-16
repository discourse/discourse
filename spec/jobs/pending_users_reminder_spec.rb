require 'spec_helper'

describe Jobs::PendingUsersReminder do

  context 'must_approve_users is true' do
    before do
      SiteSetting.stubs(:must_approve_users).returns(true)
    end

    it "doesn't send a message to anyone when there are no pending users" do
      AdminUserIndexQuery.any_instance.stubs(:find_users_query).returns(stub_everything(count: 0))
      PostCreator.expects(:create).never
      Jobs::PendingUsersReminder.new.execute({})
    end

    it "sends a message when there are pending users" do
      Fabricate(:moderator)
      Group.refresh_automatic_group!(:moderators)
      AdminUserIndexQuery.any_instance.stubs(:find_users_query).returns(stub_everything(count: 1))
      PostCreator.expects(:create).once
      Jobs::PendingUsersReminder.new.execute({})
    end
  end

  context 'must_approve_users is false' do
    before do
      SiteSetting.stubs(:must_approve_users).returns(false)
    end

    it "doesn't send a message to anyone when there are pending users" do
      AdminUserIndexQuery.any_instance.stubs(:find_users_query).returns(stub_everything(count: 1))
      PostCreator.expects(:create).never
      Jobs::PendingUsersReminder.new.execute({})
    end
  end
end
