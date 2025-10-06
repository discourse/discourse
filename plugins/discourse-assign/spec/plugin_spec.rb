# frozen_string_literal: true

RSpec.describe DiscourseAssign do
  before { SiteSetting.assign_enabled = true }

  describe "discourse-assign topics_filter_options modifier" do
    let(:user) { Fabricate(:user) }

    before do
      SiteSetting.assign_allowed_on_groups = Group::AUTO_GROUPS[:staff]
      user.update!(admin: true)
    end

    it "adds assigned filter option for users who can assign" do
      guardian = user.guardian
      options = TopicsFilter.option_info(guardian)

      assigned_option = options.find { |o| o[:name] == "assigned:" }
      expect(assigned_option).to be_present
      expect(assigned_option).to include(
        name: "assigned:",
        description: I18n.t("discourse_assign.filter.description.assigned"),
        type: "username_group_list",
        priority: 1,
      )
    end

    it "does not add assigned filter option for users who cannot assign" do
      regular_user = Fabricate(:user)
      guardian = regular_user.guardian
      options = TopicsFilter.option_info(guardian)

      assigned_option = options.find { |o| o[:name] == "assigned:" }
      expect(assigned_option).to be_nil
    end

    it "does not add assigned filter option for anonymous users" do
      options = TopicsFilter.option_info(Guardian.new)

      assigned_option = options.find { |o| o[:name] == "assigned:" }
      expect(assigned_option).to be_nil
    end
  end

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

      before { PostDestroyer.new(Discourse.system_user, post, context: "spec").destroy }

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
        PostDestroyer.new(Discourse.system_user, post, context: "spec").recover
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
