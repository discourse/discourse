# frozen_string_literal: true

RSpec.describe Jobs::PendingUsersReminder do
  context "when must_approve_users is true" do
    before do
      SiteSetting.must_approve_users = true
      Jobs::PendingUsersReminder.any_instance.stubs(:previous_newest_username).returns(nil)
    end

    it "doesn't send a message to anyone when there are no pending users" do
      PostCreator.expects(:create).never
      Jobs::PendingUsersReminder.new.execute({})
    end

    context "when there are pending users" do
      before { Fabricate(:moderator, approved: true, approved_by_id: -1, approved_at: 1.week.ago) }

      it "sends a message if user was created more than pending_users_reminder_delay minutes ago" do
        SiteSetting.pending_users_reminder_delay_minutes = 8
        Fabricate(:user, created_at: 9.minutes.ago)
        PostCreator.expects(:create).once
        Jobs::PendingUsersReminder.new.execute({})
      end

      it "doesn't send a message if user was created less than pending_users_reminder_delay minutes ago" do
        SiteSetting.pending_users_reminder_delay_minutes = 8
        Fabricate(:user, created_at: 2.minutes.ago)
        PostCreator.expects(:create).never
        Jobs::PendingUsersReminder.new.execute({})
      end

      it "doesn't send a message if pending_users_reminder_delay is -1" do
        SiteSetting.pending_users_reminder_delay_minutes = -1
        Fabricate(:user, created_at: 24.hours.ago)
        PostCreator.expects(:create).never
        Jobs::PendingUsersReminder.new.execute({})
      end

      it "sets the correct pending user count in the notification" do
        SiteSetting.pending_users_reminder_delay_minutes = 8
        Fabricate(:user, created_at: 9.minutes.ago)
        PostCreator.expects(:create).with(
          Discourse.system_user,
          has_entries(title: "1 user waiting for approval"),
        )
        Jobs::PendingUsersReminder.new.execute({})
      end
    end
  end

  context "when must_approve_users is false" do
    before { SiteSetting.must_approve_users = false }

    it "doesn't send a message to anyone when there are pending users" do
      AdminUserIndexQuery.any_instance.stubs(:find_users_query).returns(stub_everything(count: 1))
      PostCreator.expects(:create).never
      Jobs::PendingUsersReminder.new.execute({})
    end
  end
end
