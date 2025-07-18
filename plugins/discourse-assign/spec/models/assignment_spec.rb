# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assignment do
  before { SiteSetting.assign_enabled = true }

  describe ".active_for_group" do
    subject(:assignments) { described_class.active_for_group(group) }

    let!(:group) { Fabricate(:group) }
    let!(:user1) { Fabricate(:user) }
    let!(:user2) { Fabricate(:user) }
    let!(:group_user1) { Fabricate(:group_user, user: user1, group: group) }
    let!(:group_user2) { Fabricate(:group_user, user: user2, group: group) }
    let!(:wrong_group) { Fabricate(:group) }
    let!(:assignment1) { Fabricate(:topic_assignment, assigned_to: group) }
    let!(:assignment2) { Fabricate(:post_assignment, assigned_to: group) }

    before do
      Fabricate(:post_assignment, assigned_to: group, active: false)
      Fabricate(:post_assignment, assigned_to: user1)
      Fabricate(:topic_assignment, assigned_to: wrong_group)
    end

    it "returns active assignments for the group" do
      expect(assignments).to contain_exactly(assignment1, assignment2)
    end
  end

  describe ".deactivate!" do
    subject(:deactivate!) { described_class.deactivate!(topic: topic) }

    let!(:assignment1) { Fabricate(:topic_assignment) }
    let!(:assignment2) { Fabricate(:post_assignment, topic: topic) }
    let!(:assignment3) { Fabricate(:post_assignment) }
    let(:topic) { assignment1.topic }

    it "deactivates each assignment of the provided topic" do
      deactivate!
      expect([assignment1, assignment2].map(&:reload).map(&:active?)).to all eq false
      expect(assignment3.reload).to be_active
    end
  end

  describe ".reactivate!" do
    subject(:reactivate!) { described_class.reactivate!(topic: topic) }

    let!(:assignment1) { Fabricate(:topic_assignment, active: false) }
    let!(:assignment2) { Fabricate(:post_assignment, topic: topic, active: false) }
    let!(:assignment3) { Fabricate(:post_assignment, active: false) }
    let(:topic) { assignment1.topic }

    it "reactivates each assignment of the provided topic" do
      reactivate!
      expect([assignment1, assignment2].map(&:reload)).to all be_active
      expect(assignment3.reload).not_to be_active
    end
  end

  describe "#assigned_users" do
    subject(:assigned_users) { assignment.assigned_users }

    let(:assignment) { Fabricate.build(:topic_assignment, assigned_to: assigned_to) }

    context "when assigned to a group" do
      let(:assigned_to) { Fabricate.build(:group) }

      context "when group is empty" do
        it "returns an empty collection" do
          expect(assigned_users).to be_empty
        end
      end

      context "when group is not empty" do
        before { assigned_to.users = Fabricate.build_times(2, :user) }

        it "returns users from that group" do
          expect(assigned_users).to eq(assigned_to.users)
        end
      end
    end

    context "when assigned to a user" do
      let(:assigned_to) { Fabricate.build(:user) }

      it "returns that user" do
        expect(assigned_users).to eq([assigned_to])
      end
    end
  end

  describe "#post" do
    subject(:post) { assignment.post }

    context "when target is a topic" do
      let!(:initial_post) { Fabricate(:post) }
      let(:assignment) { Fabricate.build(:topic_assignment, topic: target) }
      let(:target) { initial_post.topic }

      it "returns the first post of that topic" do
        expect(post).to eq(initial_post)
      end
    end

    context "when target is a post" do
      let(:assignment) { Fabricate.build(:post_assignment) }

      it "returns that post" do
        expect(post).to eq(assignment.target)
      end
    end
  end

  describe "#create_missing_notifications!" do
    subject(:create_missing_notifications) { assignment.create_missing_notifications! }

    let(:assignment) do
      Fabricate(:topic_assignment, assigned_to: assigned_to, assigned_by_user: assigned_by_user)
    end
    let(:assigned_by_user) { Fabricate(:user) }

    context "when assigned to a user" do
      let(:assigned_to) { Fabricate(:user) }

      context "when notification already exists for that user" do
        before do
          Fabricate(
            :notification,
            notification_type: Notification.types[:assigned],
            user: assigned_to,
            data: { assignment_id: assignment.id }.to_json,
          )
        end

        it "does nothing" do
          DiscourseAssign::CreateNotification.expects(:call).never
          create_missing_notifications
        end
      end

      context "when notification does not exist yet" do
        context "when user is the one that assigned" do
          let(:assigned_by_user) { assigned_to }

          it "creates the missing notification" do
            DiscourseAssign::CreateNotification.expects(:call).with(
              assignment: assignment,
              user: assigned_to,
              mark_as_read: true,
            )
            create_missing_notifications
          end
        end

        context "when user is not the one that assigned" do
          it "creates the missing notification" do
            DiscourseAssign::CreateNotification.expects(:call).with(
              assignment: assignment,
              user: assigned_to,
              mark_as_read: false,
            )
            create_missing_notifications
          end
        end
      end
    end

    context "when assigned to a group" do
      let(:assigned_to) { Fabricate(:group) }
      let(:users) { Fabricate.times(3, :user) }
      let(:assigned_by_user) { users.last }

      before do
        assigned_to.users = users
        Fabricate(
          :notification,
          notification_type: Notification.types[:assigned],
          user: users.first,
          data: { assignment_id: assignment.id }.to_json,
        )
      end

      it "creates missing notifications for group users" do
        DiscourseAssign::CreateNotification
          .expects(:call)
          .with(assignment: assignment, user: users.first, mark_as_read: false)
          .never
        DiscourseAssign::CreateNotification.expects(:call).with(
          assignment: assignment,
          user: users.second,
          mark_as_read: false,
        )
        DiscourseAssign::CreateNotification.expects(:call).with(
          assignment: assignment,
          user: users.last,
          mark_as_read: true,
        )
        create_missing_notifications
      end
    end
  end

  describe "#reactivate!" do
    subject(:reactivate!) { assignment.reactivate! }

    fab!(:assignment) { Fabricate.create(:topic_assignment, active: false) }

    context "when target does not exist" do
      before { assignment.target.delete }

      it "does nothing" do
        expect { reactivate! }.not_to change { assignment.reload.active }
      end
    end

    context "when target exists" do
      it "sets the assignment as active" do
        expect { reactivate! }.to change { assignment.reload.active? }.to true
      end

      it "enqueues a job to create notifications" do
        reactivate!
        expect_job_enqueued(job: Jobs::AssignNotification, args: { assignment_id: assignment.id })
      end
    end
  end

  describe "#deactivate!" do
    subject(:deactivate!) { assignment.deactivate! }

    fab!(:assignment) { Fabricate.create(:topic_assignment) }

    it "sets the assignment as inactive" do
      expect { deactivate! }.to change { assignment.reload.active? }.to false
    end

    it "enqueues a job to delete notifications" do
      deactivate!
      expect_job_enqueued(
        job: Jobs::UnassignNotification,
        args: {
          topic_id: assignment.topic_id,
          assigned_to_id: assignment.assigned_to_id,
          assigned_to_type: assignment.assigned_to_type,
          assignment_id: assignment.id,
        },
      )
    end
  end
end
