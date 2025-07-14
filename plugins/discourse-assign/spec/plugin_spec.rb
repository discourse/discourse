# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAssign do
  before { SiteSetting.assign_enabled = true }

  describe "Events" do
    describe "on 'user_removed_from_group'" do
      let(:group) { Fabricate(:group) }
      let(:user) { Fabricate(:user) }
      let(:first_assignment) { Fabricate(:topic_assignment, assigned_to: group) }
      let(:second_assignment) { Fabricate(:post_assignment, assigned_to: group) }

      before do
        group.users << user
        Fabricate(
          :notification,
          notification_type: Notification.types[:assigned],
          user: user,
          data: { assignment_id: first_assignment.id }.to_json,
        )
        Fabricate(
          :notification,
          notification_type: Notification.types[:assigned],
          user: user,
          data: { assignment_id: second_assignment.id }.to_json,
        )
      end

      it "removes user's notifications related to group assignments" do
        expect { group.remove(user) }.to change { user.notifications.assigned.count }.by(-2)
      end
    end

    describe "on 'user_added_to_group'" do
      let(:group) { Fabricate(:group) }
      let(:user) { Fabricate(:user) }
      let!(:first_assignment) { Fabricate(:topic_assignment, assigned_to: group) }
      let!(:second_assignment) { Fabricate(:post_assignment, assigned_to: group) }
      let!(:third_assignment) { Fabricate(:topic_assignment, assigned_to: group, active: false) }

      it "creates missing notifications for added user" do
        group.add(user)
        [first_assignment, second_assignment].each do |assignment|
          expect_job_enqueued(job: Jobs::AssignNotification, args: { assignment_id: assignment.id })
        end
        expect(
          job_enqueued?(
            job: Jobs::AssignNotification,
            args: {
              assignment_id: third_assignment.id,
            },
          ),
        ).to eq(false)
      end
    end

    describe "on 'topic_status_updated'" do
      context "when closing a topic" do
        let!(:first_assignment) { Fabricate(:topic_assignment) }
        let!(:second_assignment) { Fabricate(:post_assignment, topic: topic) }
        let(:topic) { first_assignment.topic }

        before do
          SiteSetting.unassign_on_close = true
          topic.update_status("closed", true, Discourse.system_user)
        end

        it "deactivates existing assignments" do
          [first_assignment, second_assignment].each do |assignment|
            assignment.reload
            expect(assignment).not_to be_active
            expect_job_enqueued(
              job: Jobs::UnassignNotification,
              args: {
                topic_id: assignment.topic_id,
                assignment_id: assignment.id,
                assigned_to_id: assignment.assigned_to_id,
                assigned_to_type: assignment.assigned_to_type,
              },
            )
          end
        end
      end

      context "when reopening a topic" do
        let!(:topic) { Fabricate(:closed_topic) }
        let!(:first_assignment) { Fabricate(:topic_assignment, topic: topic, active: false) }
        let!(:second_assignment) { Fabricate(:post_assignment, topic: topic, active: false) }

        before do
          SiteSetting.reassign_on_open = true
          topic.update_status("closed", false, Discourse.system_user)
        end

        it "reactivates existing assignments" do
          [first_assignment, second_assignment].each do |assignment|
            assignment.reload
            expect(assignment).to be_active
            expect_job_enqueued(
              job: Jobs::AssignNotification,
              args: {
                assignment_id: assignment.id,
              },
            )
          end
        end
      end
    end

    describe "on 'post_destroyed'" do
      let!(:assignment) { Fabricate(:post_assignment) }
      let(:post) { assignment.target }

      before { PostDestroyer.new(Discourse.system_user, post).destroy }

      it "deactivates the existing assignment" do
        assignment.reload
        expect(assignment).not_to be_active
        expect_job_enqueued(
          job: Jobs::UnassignNotification,
          args: {
            topic_id: assignment.topic_id,
            assignment_id: assignment.id,
            assigned_to_id: assignment.assigned_to_id,
            assigned_to_type: assignment.assigned_to_type,
          },
        )
      end
    end

    describe "on 'post_recovered'" do
      let!(:assignment) { Fabricate(:post_assignment, active: false) }
      let(:post) { assignment.target }

      before do
        SiteSetting.reassign_on_open = true
        post.trash!
        PostDestroyer.new(Discourse.system_user, post).recover
      end

      it "reactivates the existing assignment" do
        assignment.reload
        expect(assignment).to be_active
        expect_job_enqueued(job: Jobs::AssignNotification, args: { assignment_id: assignment.id })
      end
    end

    describe "on 'group_destroyed'" do
      let(:group) { Fabricate(:group) }
      let(:user) { Fabricate(:user) }
      let(:first_assignment) { Fabricate(:topic_assignment, assigned_to: group) }
      let(:second_assignment) { Fabricate(:post_assignment, assigned_to: group) }

      before do
        group.users << user
        Fabricate(
          :notification,
          notification_type: Notification.types[:assigned],
          user: user,
          data: { assignment_id: first_assignment.id }.to_json,
        )
        Fabricate(
          :notification,
          notification_type: Notification.types[:assigned],
          user: user,
          data: { assignment_id: second_assignment.id }.to_json,
        )
      end

      it "removes user's notifications related to group assignments" do
        expect { group.destroy }.to change { user.notifications.assigned.count }.by(-2)
      end
    end
  end
end
