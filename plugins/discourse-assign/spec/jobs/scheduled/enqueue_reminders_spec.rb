# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::EnqueueReminders do
  fab!(:assign_allowed_group) { Fabricate(:group) }
  fab!(:user) { Fabricate(:user, groups: [assign_allowed_group]) }

  before do
    SiteSetting.remind_assigns_frequency = RemindAssignsFrequencySiteSettings::MONTHLY_MINUTES
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = "#{assign_allowed_group.id}"
  end

  describe "#execute" do
    it "does not enqueue reminders when there are no assigned tasks" do
      assert_reminders_enqueued(0)
    end

    it "does not enqueue reminders when no groups are allowed to assign" do
      SiteSetting.assign_allowed_on_groups = ""

      assign_multiple_tasks_to(user)

      assert_reminders_enqueued(0)
    end

    it "enqueues a reminder when the user has more than one task" do
      assign_multiple_tasks_to(user)

      assert_reminders_enqueued(1)
    end

    it "does not enqueue a reminder when the user has fewer assignments than `pending_assign_reminder_threshold`" do
      assign_one_task_to(user)

      assert_reminders_enqueued(0)
    end

    it "enqueues a reminder when the user has one assignement if `pending_assign_reminder_threshold` is set to one" do
      assign_one_task_to(user)

      SiteSetting.pending_assign_reminder_threshold = 1

      assert_reminders_enqueued(1)
    end

    it "doesn't count assigns from deleted topics" do
      deleted_post = Fabricate(:post)
      assign_one_task_to(user, post: deleted_post)
      (SiteSetting.pending_assign_reminder_threshold - 1).times { assign_one_task_to(user) }

      deleted_post.topic.trash!

      assert_reminders_enqueued(0)
    end

    describe "assignment frequency" do
      it "enqueues a reminder if the user reminder frequency is 1 day and the last reminded at is almost 1 day" do
        user.custom_fields[
          PendingAssignsReminder::REMINDERS_FREQUENCY
        ] = RemindAssignsFrequencySiteSettings::DAILY_MINUTES
        user.custom_fields[PendingAssignsReminder::REMINDED_AT] = 1.days.ago +
          (Jobs::EnqueueReminders::REMINDER_BUFFER_MINUTES - 1)
        user.save

        assign_multiple_tasks_to(user, assigned_on: 2.day.ago)

        assert_reminders_enqueued(1)
      end

      it "does not enqueue a reminder if it's too soon" do
        user.upsert_custom_fields(
          PendingAssignsReminder::REMINDED_AT =>
            1.days.ago + Jobs::EnqueueReminders::REMINDER_BUFFER_MINUTES,
        )
        assign_multiple_tasks_to(user)

        assert_reminders_enqueued(0)
      end

      it "enqueues a reminder if the user was reminded more than a month ago" do
        user.upsert_custom_fields(PendingAssignsReminder::REMINDED_AT => 31.days.ago)
        assign_multiple_tasks_to(user)

        assert_reminders_enqueued(1)
      end

      it "does not enqueue reminders if the remind frequency is set to never" do
        SiteSetting.remind_assigns_frequency = 0
        assign_multiple_tasks_to(user)

        assert_reminders_enqueued(0)
      end

      it "does not enqueue reminders if the topic was just assigned to the user" do
        just_assigned = DateTime.now
        assign_multiple_tasks_to(user, assigned_on: just_assigned)

        assert_reminders_enqueued(0)
      end

      it "enqueues a reminder when the user overrides the global frequency" do
        SiteSetting.remind_assigns_frequency = 0
        user.custom_fields.merge!(
          PendingAssignsReminder::REMINDERS_FREQUENCY =>
            RemindAssignsFrequencySiteSettings::DAILY_MINUTES,
        )
        user.save_custom_fields

        assign_multiple_tasks_to(user)

        assert_reminders_enqueued(1)
      end
    end

    def assert_reminders_enqueued(expected_amount)
      expect { subject.execute({}) }.to change(Jobs::RemindUser.jobs, :size).by(expected_amount)
    end

    def assign_one_task_to(user, assigned_on: 3.months.ago, post: Fabricate(:post))
      freeze_time(assigned_on) { Assigner.new(post.topic, user).assign(user) }
    end

    def assign_multiple_tasks_to(user, assigned_on: 3.months.ago)
      SiteSetting.pending_assign_reminder_threshold.times do
        assign_one_task_to(user, assigned_on: assigned_on)
      end
    end
  end
end
