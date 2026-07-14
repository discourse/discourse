# frozen_string_literal: true

require_relative "../support/assign_allowed_group"

RSpec.describe DiscourseAssign::AssignController do
  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = "#{allowed_group.id}|#{staff_group.id}"
  end

  fab!(:staff_group) { Group.find_by(name: "staff") }
  fab!(:non_allowed_group, :group)
  fab!(:allowed_group, :group)

  fab!(:admin)
  fab!(:allowed_user) { Fabricate(:user, username: "mads", name: "Mads", groups: [allowed_group]) }
  fab!(:non_admin_staff) { Fabricate(:user, groups: [staff_group]) }
  fab!(:user_in_non_allowed_group) { Fabricate(:user, groups: [non_allowed_group]) }

  fab!(:post)

  describe "only allow users from allowed groups to assign" do
    it "filters requests where current_user is not member of an allowed group" do
      sign_in(user_in_non_allowed_group)

      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: admin.username,
          }

      expect(response.status).to eq(403)
    end

    it "filters requests where assigned group is not allowed" do
      sign_in(admin)

      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            group_name: non_allowed_group.name,
          }

      expect(response.status).to eq(400)
    end
  end

  describe "#suggestions" do
    before { sign_in(admin) }

    it "only includes users in allowed groups and not disallowed groups" do
      Assigner.new(post.topic, admin).assign(allowed_user)

      get "/assign/suggestions.json"
      suggestions = JSON.parse(response.body)["suggestions"].map { |u| u["username"] }

      expect(suggestions).to contain_exactly(allowed_user.username, admin.username)
      expect(suggestions).to_not include(user_in_non_allowed_group)
    end

    it "does include only visible assign_allowed_on_groups" do
      sign_in(non_admin_staff) # Need to use non-admin to test. Admins can see all groups

      visible_group = Fabricate(:group, visibility_level: Group.visibility_levels[:members])
      visible_group.add(non_admin_staff)
      invisible_group = Fabricate(:group, visibility_level: Group.visibility_levels[:members])

      SiteSetting.assign_allowed_on_groups = "#{visible_group.id}|#{invisible_group.id}"

      get "/assign/suggestions.json"
      assign_allowed_on_groups = JSON.parse(response.body)["assign_allowed_on_groups"]

      expect(assign_allowed_on_groups).to contain_exactly(visible_group.name)
    end

    it "suggests the current user + the last 5 previously assigned users" do
      assignees = 6.times.map { |_| assign_user_to_post.username }

      get "/assign/suggestions.json"

      suggestions = response.parsed_body["suggestions"].map { |u| u["username"] }
      expect(suggestions).to contain_exactly(admin.username, *assignees[1..5])
    end

    it "doesn't suggest users on holiday" do
      user_on_vacation = assign_user_to_post
      user_on_vacation.upsert_custom_fields(
        DiscourseAssign::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD => "t",
      )

      get "/assign/suggestions.json"

      suggestions = response.parsed_body["suggestions"].map { |u| u["username"] }
      expect(suggestions).to_not include(user_on_vacation.username)
    end

    it "suggests the current user even if they're on holiday" do
      admin.upsert_custom_fields(DiscourseAssign::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD => "t")

      get "/assign/suggestions.json"

      suggestions = response.parsed_body["suggestions"].map { |u| u["username"] }
      expect(suggestions).to include(admin.username)
    end

    it "excludes other users from the suggestions when they already reached the max assigns limit" do
      SiteSetting.max_assigned_topics = 1
      another_user = Fabricate(:user)
      Fabricate(:post_assignment, assigned_to: another_user, assigned_by_user: admin)

      get "/assign/suggestions.json"
      suggestions = JSON.parse(response.body)["suggestions"].map { |u| u["username"] }

      expect(suggestions).to contain_exactly(admin.username)
    end

    it "returns target scoped groups when suggestions are requested for a scoped category" do
      SiteSetting.assign_allowed_on_groups = ""
      category = Fabricate(:category)
      topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: category) }
      scoped_group = Fabricate(:group)
      scoped_user = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(category, scoped_group)

      sign_in(scoped_user)
      get "/assign/suggestions.json", params: { target_id: topic.id, target_type: "Topic" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["assign_allowed_on_groups"]).to contain_exactly(scoped_group.name)
      expect(response.parsed_body["assign_allowed_for_groups"]).to contain_exactly(
        scoped_group.name,
      )
    end

    def assign_user_to_post
      assignee = Fabricate(:user, groups: [allowed_group])
      Fabricate(:post_assignment, assigned_to: assignee, assigned_by_user: admin)
      assignee
    end
  end

  describe "#unassign" do
    include_context "with group that is allowed to assign"

    it "returns 404 when the acting user cannot see the target topic" do
      restricted_group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: restricted_group)
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(
        :topic_assignment,
        target: private_topic,
        assigned_to: admin,
        assigned_by_user: admin,
      )

      sign_in(allowed_user)

      put "/assign/unassign.json", params: { target_id: private_topic.id, target_type: "Topic" }
      expect(response.status).to eq(404)
    end

    it "returns 404 when the acting user cannot see the target PM" do
      pm_topic = Fabricate(:private_message_topic)
      Fabricate(:topic_assignment, target: pm_topic, assigned_to: admin, assigned_by_user: admin)

      sign_in(allowed_user)

      put "/assign/unassign.json", params: { target_id: pm_topic.id, target_type: "Topic" }
      expect(response.status).to eq(404)
    end

    it "only allows category scoped users to unassign topics in the scoped category" do
      SiteSetting.assign_allowed_on_groups = ""
      allowed_category = Fabricate(:category)
      other_category = Fabricate(:category)
      allowed_topic =
        Fabricate(:post).topic.tap { |topic| topic.update!(category: allowed_category) }
      other_topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: other_category) }
      scoped_group = Fabricate(:group)
      scoped_user = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(allowed_category, scoped_group)
      Fabricate(
        :topic_assignment,
        target: allowed_topic,
        assigned_to: admin,
        assigned_by_user: admin,
      )
      Fabricate(:topic_assignment, target: other_topic, assigned_to: admin, assigned_by_user: admin)

      sign_in(scoped_user)
      put "/assign/unassign.json", params: { target_id: other_topic.id, target_type: "Topic" }
      expect(response.status).to eq(403)
      expect(other_topic.reload.assignment).to be_present

      put "/assign/unassign.json", params: { target_id: allowed_topic.id, target_type: "Topic" }
      expect(response.status).to eq(200)
      expect(allowed_topic.reload.assignment).to be_blank
    end
  end

  describe "#assign" do
    include_context "with group that is allowed to assign"

    before do
      sign_in(admin)
      SiteSetting.enable_assign_status = true
    end

    it "returns 404 when the acting user cannot see the target topic" do
      restricted_group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: restricted_group)
      private_topic = Fabricate(:topic, category: private_category)
      add_to_assign_allowed_group(allowed_user)

      sign_in(allowed_user)

      put "/assign/assign.json",
          params: {
            target_id: private_topic.id,
            target_type: "Topic",
            username: admin.username,
          }
      expect(response.status).to eq(404)
    end

    it "returns 404 when the acting user cannot see the target PM" do
      pm_topic = Fabricate(:private_message_topic)
      add_to_assign_allowed_group(allowed_user)

      sign_in(allowed_user)

      put "/assign/assign.json",
          params: {
            target_id: pm_topic.id,
            target_type: "Topic",
            username: admin.username,
          }
      expect(response.status).to eq(404)
    end

    it "assigns topic to a user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
          }

      expect(response.status).to eq(200)
      expect(post.topic.reload.assignment.assigned_to_id).to eq(allowed_user.id)
    end

    it "does not assign to a group hidden from the acting user" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:staff],
          assignable_level: Group::ALIAS_LEVELS[:everyone],
        )

      sign_in(allowed_user)

      get "/g/#{hidden_group.name}.json"
      expect(response.status).to eq(404)

      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            group_name: hidden_group.name,
          }

      expect(response.status).to eq(403)
      expect(response.body).not_to include(hidden_group.name)
      expect(post.topic.reload.assignment).to be_nil
    end

    it "assigns topic with note to a user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
            note: "do dis pls",
          }

      expect(post.topic.reload.assignment.note).to eq("do dis pls")
    end

    it "assigns topic with a set status to a user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
            status: "In Progress",
          }

      expect(post.topic.reload.assignment.status).to eq("In Progress")
    end

    it "assigns topic with default status to a user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
          }

      expect(post.topic.reload.assignment.status).to eq("New")
    end

    it "assigns topic to a group" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            group_name: assign_allowed_group.name,
          }

      expect(response.status).to eq(200)
      expect(post.topic.reload.assignment.assigned_to).to eq(assign_allowed_group)
    end

    it "only allows category scoped users to assign in the exact scoped category" do
      SiteSetting.assign_allowed_on_groups = ""
      parent_category = Fabricate(:category)
      child_category = Fabricate(:category, parent_category: parent_category)
      parent_topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: parent_category) }
      child_topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: child_category) }
      scoped_group = Fabricate(:group)
      scoped_user = Fabricate(:user, groups: [scoped_group])
      assignee = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(parent_category, scoped_group)

      sign_in(scoped_user)
      put "/assign/assign.json",
          params: {
            target_id: parent_topic.id,
            target_type: "Topic",
            username: assignee.username,
          }
      expect(response.status).to eq(200)
      expect(parent_topic.reload.assignment.assigned_to).to eq(assignee)

      put "/assign/assign.json",
          params: {
            target_id: child_topic.id,
            target_type: "Topic",
            username: assignee.username,
          }
      expect(response.status).to eq(400)
      expect(response.parsed_body["error"]).to eq(
        I18n.t("discourse_assign.forbidden_assigner_not_allowed"),
      )
    end

    it "fails to assign topic to the user if its already assigned to the same user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
          }

      expect(response.status).to eq(200)
      expect(post.topic.reload.assignment.assigned_to_id).to eq(allowed_user.id)

      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
          }

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)["error"]).to eq(
        I18n.t("discourse_assign.already_assigned", username: allowed_user.username),
      )
    end

    it "fails to assign topic to the user if they already reached the max assigns limit" do
      another_user = Fabricate(:user)
      add_to_assign_allowed_group(another_user)
      another_post = Fabricate(:post)
      max_assigns = 1
      SiteSetting.max_assigned_topics = max_assigns
      Assigner.new(post.topic, admin).assign(another_user)

      put "/assign/assign.json",
          params: {
            target_id: another_post.topic_id,
            target_type: "Topic",
            username: another_user.username,
          }

      expect(response.status).to eq(400)
      expect(JSON.parse(response.body)["error"]).to eq(
        I18n.t(
          "discourse_assign.too_many_assigns",
          username: another_user.username,
          max: max_assigns,
        ),
      )
    end

    it "fails with a specific error message if the topic is a PM and the assignee can not see it" do
      pm = Fabricate(:private_message_post, user: admin).topic
      another_user = Fabricate(:user)
      add_to_assign_allowed_group(another_user)
      put "/assign/assign.json",
          params: {
            target_id: pm.id,
            target_type: "Topic",
            username: another_user.username,
          }

      expect(response.parsed_body["error"]).to eq(
        I18n.t(
          "discourse_assign.forbidden_assignee_not_pm_participant",
          username: another_user.username,
        ),
      )
    end

    it "notifies the assignee when the topic is assigned to a group" do
      admins = Group[:admins]
      admins.messageable_level = Group::ALIAS_LEVELS[:everyone]
      admins.assignable_level = Group::ALIAS_LEVELS[:everyone]
      admins.save!

      SiteSetting.invite_on_assign = true
      pm = Fabricate(:private_message_post, user: admin).topic

      another_user = Fabricate(:user)
      admins.add(another_user)
      admins
        .group_users
        .find_by(user_id: another_user.id)
        .update!(notification_level: NotificationLevels.all[:watching])

      Notification.delete_all
      Jobs.run_immediately!

      put "/assign/assign.json",
          params: {
            target_id: pm.id,
            target_type: "Topic",
            group_name: admins.name,
          }

      expect(Notification.count).to be > 0
    end

    it "does not notify the assignee when the topic is assigned to a group if should_notify option is set to false" do
      admins = Group[:admins]
      admins.messageable_level = Group::ALIAS_LEVELS[:everyone]
      admins.assignable_level = Group::ALIAS_LEVELS[:everyone]
      admins.save!

      SiteSetting.invite_on_assign = true
      pm = Fabricate(:private_message_post, user: admin).topic

      another_user = Fabricate(:user)
      admins.add(another_user)
      admins
        .group_users
        .find_by(user_id: another_user.id)
        .update!(notification_level: NotificationLevels.all[:watching])

      Notification.delete_all
      Jobs.run_immediately!

      put "/assign/assign.json",
          params: {
            target_id: pm.id,
            target_type: "Topic",
            group_name: admins.name,
            should_notify: false,
          }
      expect(Notification.count).to eq(0)
      expect(SilencedAssignment.count).to eq(1)
    end

    it "fails with a specific error message if the topic is not a PM and the assignee can not see it" do
      topic = Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))
      another_user = Fabricate(:user)
      add_to_assign_allowed_group(another_user)
      put "/assign/assign.json",
          params: {
            target_id: topic.id,
            target_type: "Topic",
            username: another_user.username,
          }

      expect(response.parsed_body["error"]).to eq(
        I18n.t(
          "discourse_assign.forbidden_assignee_cant_see_topic",
          username: another_user.username,
        ),
      )
    end
  end

  describe "#assigned" do
    fab!(:topic1) { Fabricate(:topic, bumped_at: 1.hour.from_now) }
    fab!(:topic2) { Fabricate(:topic, bumped_at: 2.hours.from_now) }
    fab!(:topic3) { Fabricate(:topic, bumped_at: 3.hours.from_now) }

    fab!(:assignments) do
      Fabricate(
        :topic_assignment,
        target: topic1,
        assigned_to: allowed_user,
        assigned_by_user: admin,
      )
      Fabricate(:topic_assignment, target: topic2, assigned_to: admin, assigned_by_user: admin)
      Fabricate(
        :topic_assignment,
        target: topic3,
        assigned_to: allowed_user,
        assigned_by_user: admin,
      )
    end

    before { sign_in(admin) }

    it "lists topics ordered by user id" do
      get "/assign/assigned.json"
      expect(JSON.parse(response.body)["topics"].map { |t| t["id"] }).to match_array(
        [topic2.id, topic1.id, topic3.id],
      )

      get "/assign/assigned.json", params: { limit: 2 }
      expect(JSON.parse(response.body)["topics"].map { |t| t["id"] }).to match_array(
        [topic3.id, topic2.id],
      )

      get "/assign/assigned.json", params: { offset: 2 }
      expect(JSON.parse(response.body)["topics"].map { |t| t["id"] }).to match_array([topic1.id])
    end

    context "with custom allowed groups" do
      let(:custom_allowed_group) { Fabricate(:group, name: "my-group") }
      let(:other_user) { Fabricate(:user, groups: [custom_allowed_group]) }

      before { SiteSetting.assign_allowed_on_groups += "|#{custom_allowed_group.id}" }

      it "works for admins" do
        get "/assign/assigned.json"
        expect(response.status).to eq(200)
      end

      it "does not work for other groups" do
        sign_in(other_user)
        get "/assign/assigned.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "#group_members" do
    fab!(:other_allowed_user) { Fabricate(:user, groups: [allowed_group]) }

    fab!(:topic)
    fab!(:post_in_same_topic) { Fabricate(:post, topic: topic) }

    fab!(:assignments) do
      Fabricate(
        :topic_assignment,
        assigned_to: other_allowed_user,
        target: topic,
        assigned_by_user: admin,
      )

      Fabricate(
        :post_assignment,
        assigned_to: other_allowed_user,
        target: post_in_same_topic,
        assigned_by_user: admin,
      )

      Fabricate(:topic_assignment, assigned_to: allowed_user, assigned_by_user: admin)
      Fabricate(:topic_assignment, assigned_to: other_allowed_user, assigned_by_user: admin)

      Fabricate(:topic_assignment, assigned_to: allowed_group, assigned_by_user: admin)
      Fabricate(:post_assignment, assigned_to: allowed_group, assigned_by_user: admin)
    end

    it "does not list members for a group hidden from the user" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:staff],
          members_visibility_level: Group.visibility_levels[:logged_on_users],
        )
      hidden_member = Fabricate(:user)
      hidden_group.add(hidden_member)
      Fabricate(:topic_assignment, assigned_to: hidden_member, assigned_by_user: admin)

      sign_in(allowed_user)

      get "/g/#{hidden_group.name}.json"
      expect(response.status).to eq(404)

      get "/assign/members/#{hidden_group.name}.json"
      expect(response.status).to eq(403)
      expect(
        response.parsed_body.fetch("members", []).map { |member| member["username"] },
      ).not_to include(hidden_member.username)
    end

    describe "members" do
      describe "without filter" do
        it "list members ordered by the number of assignments" do
          sign_in(admin)

          get "/assign/members/#{allowed_group.name}.json"
          members = JSON.parse(response.body)["members"]

          expect(response.status).to eq(200)
          expect(members[0]).to include({ "id" => other_allowed_user.id, "assignments_count" => 3 })
          expect(members[1]).to include({ "id" => allowed_user.id, "assignments_count" => 1 })
        end

        it "doesn't include members with no assignments" do
          sign_in(admin)
          allowed_group.users << non_admin_staff

          get "/assign/members/#{allowed_group.name}.json"
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["members"].map { |m| m["id"] }).to_not include(
            non_admin_staff.id,
          )
        end
      end

      describe "with filter" do
        it "returns members as according to filter" do
          sign_in(admin)

          get "/assign/members/#{allowed_group.name}.json", params: { filter: "a" }
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["members"].map { |m| m["id"] }).to match_array(
            [other_allowed_user.id, allowed_user.id],
          )

          get "/assign/members/#{allowed_group.name}.json",
              params: {
                filter: "#{allowed_user.username}",
              }
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["members"].map { |m| m["id"] }).to match_array(
            [allowed_user.id],
          )

          get "/assign/members/#{allowed_group.name}.json",
              params: {
                filter: "#{allowed_user.name}",
              }
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)["members"].map { |m| m["id"] }).to match_array(
            [allowed_user.id],
          )
        end
      end
    end

    describe "assignment_count" do
      it "returns the total number of assignments for group users and the group" do
        sign_in(admin)

        get "/assign/members/#{allowed_group.name}.json"

        expect(JSON.parse(response.body)["assignment_count"]).to eq(6)
      end
    end

    describe "group_assignment_count" do
      it "returns the number of assignments assigned to the group" do
        sign_in(admin)

        get "/assign/members/#{allowed_group.name}.json"

        expect(JSON.parse(response.body)["group_assignment_count"]).to eq(2)
      end
    end

    it "404 error to non-group-members" do
      normal_user = Fabricate(:user)

      sign_in(normal_user)

      get "/assign/members/#{allowed_group.name}.json"
      expect(response.status).to eq(403)
    end

    it "returns 403 for users who can only assign in scoped categories" do
      SiteSetting.assign_allowed_on_groups = ""
      category = Fabricate(:category)
      scoped_group = Fabricate(:group)
      scoped_user = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(category, scoped_group)

      sign_in(scoped_user)

      get "/assign/members/#{scoped_group.name}.json"
      expect(response.status).to eq(403)
    end

    it "allows non-member-admin" do
      non_member_admin = Fabricate(:admin)

      sign_in(non_member_admin)

      get "/assign/members/#{allowed_group.name}.json"
      expect(response.status).to eq(200)
    end
  end
end
