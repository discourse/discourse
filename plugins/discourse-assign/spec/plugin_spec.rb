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

    it "does not add assigned filter option for scoped users" do
      SiteSetting.assign_allowed_on_groups = ""
      category = Fabricate(:category)
      scoped_group = Fabricate(:group)
      scoped_user = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(category, scoped_group)

      options = TopicsFilter.option_info(scoped_user.guardian)

      assigned_option = options.find { |option| option[:name] == "assigned:" }
      expect(assigned_option).to be_nil
    end

    it "does not add assigned filter option for anonymous users" do
      options = TopicsFilter.option_info(Guardian.new)

      assigned_option = options.find { |o| o[:name] == "assigned:" }
      expect(assigned_option).to be_nil
    end
  end

  describe "discourse-assign TopicsFilter filtering" do
    fab!(:group)
    fab!(:user)

    fab!(:post_assignment) { Fabricate(:post_assignment, assigned_to: user) }
    fab!(:topic_assignment) { Fabricate(:topic_assignment, assigned_to: group) }

    before do
      SiteSetting.assign_allowed_on_groups = "#{group.id}"
      group.add(user)
    end

    describe "with assigned:username" do
      it "returns topics assigned to the specified user" do
        filtered_topic_ids =
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("assigned:#{user.username}")
            .pluck(:id)
        expect(filtered_topic_ids).to contain_exactly(post_assignment.topic.id)
      end
    end

    describe "with assigned:group" do
      it "returns topics assigned to the specified group" do
        filtered_topic_ids =
          TopicsFilter
            .new(guardian: Guardian.new(user))
            .filter_from_query_string("assigned:#{group.name}")
            .pluck(:id)
        expect(filtered_topic_ids).to contain_exactly(topic_assignment.topic.id)
      end

      describe "when querying private groups" do
        fab!(:private_group) do
          Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
        end

        fab!(:private_topic_assignment) { Fabricate(:topic_assignment, assigned_to: private_group) }

        it "does not return topics from private groups the user is not a member of" do
          filtered_topic_ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("assigned:#{private_group.name}")
              .pluck(:id)
          expect(filtered_topic_ids).to be_empty
        end

        it "does not return topics from private groups the user is a member of but lacks access to" do
          private_group.add(user)

          filtered_topic_ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("assigned:#{private_group.name}")
              .pluck(:id)
          expect(filtered_topic_ids).to be_empty
        end

        it "returns topics from private groups the user has access to" do
          private_group.add_owner(user)

          filtered_topic_ids =
            TopicsFilter
              .new(guardian: Guardian.new(user))
              .filter_from_query_string("assigned:#{private_group.name}")
              .pluck(:id)
          expect(filtered_topic_ids).to contain_exactly(private_topic_assignment.topic.id)
        end
      end
    end
  end

  describe "discourse-assign posts_filter_options modifier" do
    let(:user) { Fabricate(:user) }

    before do
      SiteSetting.assign_allowed_on_groups = Group::AUTO_GROUPS[:staff]
      user.update!(admin: true)
    end

    it "adds assigned_to filter option for users who can assign" do
      options = PostsFilter.option_info(user.guardian)

      assigned_option = options.find { |option| option[:name] == "assigned_to:" }
      expect(assigned_option).to include(
        name: "assigned_to:",
        description: I18n.t("discourse_assign.filter.description.assigned"),
        type: "username",
        priority: 1,
      )
    end

    it "does not add assigned_to filter option for users who cannot assign" do
      options = PostsFilter.option_info(Fabricate(:user).guardian)

      assigned_option = options.find { |option| option[:name] == "assigned_to:" }
      expect(assigned_option).to be_nil
    end
  end

  describe "discourse-assign PostsFilter filtering" do
    fab!(:group)
    fab!(:user)
    fab!(:assigned_post, :post)
    fab!(:other_assigned_post, :post)
    fab!(:unassigned_post, :post)
    fab!(:post_assignment) { Fabricate(:post_assignment, post: assigned_post, assigned_to: user) }
    fab!(:other_assignment) do
      Fabricate(:post_assignment, post: other_assigned_post, assigned_to: Fabricate(:user))
    end

    before do
      SiteSetting.assign_allowed_on_groups = "#{group.id}"
      group.add(user)
    end

    it "filters posts by assigned user" do
      filtered_post_ids =
        PostsFilter
          .new("assigned_to:#{user.username}", guardian: Guardian.new(user))
          .search
          .pluck(:id)

      expect(filtered_post_ids).to contain_exactly(assigned_post.id)
    end

    it "filters posts by assigned and unassigned topics" do
      assigned_post_ids =
        PostsFilter.new("assigned_to:*", guardian: Guardian.new(user)).search.pluck(:id)
      unassigned_post_ids =
        PostsFilter.new("assigned_to:nobody", guardian: Guardian.new(user)).search.pluck(:id)

      expect(assigned_post_ids).to contain_exactly(assigned_post.id, other_assigned_post.id)
      expect(unassigned_post_ids).to include(unassigned_post.id)
    end

    it "raises when the user cannot see assignments" do
      expect do
        PostsFilter
          .new("assigned_to:#{user.username}", guardian: Guardian.new(Fabricate(:user)))
          .search
          .load
      end.to raise_error(Discourse::InvalidAccess)
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

    describe "on 'user_added_to_group'" do
      fab!(:group)
      fab!(:user)
      fab!(:assigned_by_user, :user)
      fab!(:visible_user, :user)
      fab!(:private_message_post) do
        Fabricate(:private_message_post, user: assigned_by_user, recipient: visible_user)
      end
      fab!(:assignment) do
        Fabricate(
          :topic_assignment,
          topic: private_message_post.topic,
          target: private_message_post.topic,
          assigned_to: group,
          assigned_by_user: assigned_by_user,
        )
      end

      before { Jobs.run_immediately! }

      it "does not create notifications for users who cannot see the assignment target" do
        expect(Guardian.new(user).can_see_topic?(private_message_post.topic)).to eq(false)

        expect { group.add(user) }.not_to change { user.notifications.assigned.count }
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
