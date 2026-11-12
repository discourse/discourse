# frozen_string_literal: true

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

    def assign_user_to_post
      assignee = Fabricate(:user, groups: [allowed_group])
      Fabricate(:post_assignment, assigned_to: assignee, assigned_by_user: admin)
      assignee
    end

    def suggested_usernames
      response.parsed_body["suggestions"].map { |user| user["username"] }
    end

    it "only suggests recent assignees who can still be assigned" do
      Assigner.new(post.topic, admin).assign(allowed_user)
      Fabricate(:post_assignment, assigned_to: user_in_non_allowed_group, assigned_by_user: admin)

      get "/assign/suggestions.json"

      expect(suggested_usernames).to contain_exactly(allowed_user.username, admin.username)
    end

    it "suggests the current user + the last 5 previously assigned users" do
      assignees = 6.times.map { |_| assign_user_to_post.username }

      get "/assign/suggestions.json"

      expect(suggested_usernames).to contain_exactly(admin.username, *assignees[1..5])
    end

    it "doesn't suggest users on holiday, except the current user" do
      user_on_vacation = assign_user_to_post
      [user_on_vacation, admin].each do |user|
        user.upsert_custom_fields(DiscourseAssign::DiscourseCalendar::HOLIDAY_CUSTOM_FIELD => "t")
      end

      get "/assign/suggestions.json"

      expect(suggested_usernames).to contain_exactly(admin.username)
    end

    it "excludes other users from the suggestions when they already reached the max assigns limit" do
      SiteSetting.max_assigned_topics = 1
      another_user = Fabricate(:user)
      Fabricate(:post_assignment, assigned_to: another_user, assigned_by_user: admin)

      get "/assign/suggestions.json"

      expect(suggested_usernames).to contain_exactly(admin.username)
    end

    it "suggests the visible groups assignable on the target" do
      SiteSetting.assign_allowed_on_groups = ""
      topic = Fabricate(:topic, category: Fabricate(:category))
      scoped_group = Fabricate(:group)
      hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
      scoped_user = Fabricate(:user, groups: [scoped_group])
      allow_group_to_assign_in_category(topic.category, scoped_group, hidden_group)

      sign_in(scoped_user)
      get "/assign/suggestions.json", params: { target_id: topic.id, target_type: "Topic" }

      expect(response.parsed_body["groups"].map { |group| group["name"] }).to contain_exactly(
        scoped_group.name,
      )
    end
  end

  describe "#search" do
    before_all { SearchIndexer.enable }

    fab!(:team_a) do
      Fabricate(
        :group,
        name: "team_a",
        members_visibility_level: Group.visibility_levels[:members],
        assignable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
      )
    end
    fab!(:team_b) do
      Fabricate(
        :group,
        name: "team_b",
        members_visibility_level: Group.visibility_levels[:members],
        assignable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
      )
    end
    fab!(:assigner) { Fabricate(:user, username: "assigner", groups: [team_a]) }
    fab!(:target_alice) { Fabricate(:user, username: "target_alice", groups: [team_a]) }
    fab!(:target_bob) { Fabricate(:user, username: "target_bob", groups: [team_b]) }
    fab!(:target_carol) { Fabricate(:user, username: "target_carol", groups: [non_allowed_group]) }
    fab!(:target_admin) { Fabricate(:admin, username: "target_admin") }

    let(:topic) { post.topic }

    before { SiteSetting.assign_allowed_on_groups = "#{team_a.id}|#{team_b.id}" }

    def search(term, target = topic)
      params = { term: }
      params.merge!(target_id: target.id, target_type: target.class.name) if target
      get "/assign/search.json", params:
    end

    def usernames
      response.parsed_body["users"].map { |user| user["username"] }
    end

    def group_names
      response.parsed_body["groups"].map { |group| group["name"] }
    end

    it "finds assignable users, even in groups whose members the assigner cannot see" do
      sign_in(assigner)
      search("target")

      expect(usernames).to contain_exactly(
        target_alice.username,
        target_bob.username,
        target_admin.username,
      )
    end

    it "finds visible groups the assigner can assign on the target" do
      scoped_group = Fabricate(:group, name: "team_scoped")
      hidden_group =
        Fabricate(:group, name: "team_hidden", visibility_level: Group.visibility_levels[:owners])
      allow_group_to_assign_in_category(topic.category, scoped_group, hidden_group)
      sign_in(assigner)

      search("team")

      expect(group_names).to contain_exactly(team_a.name, scoped_group.name)
    end

    it "rejects blank terms and targets the assigner cannot see" do
      sign_in(assigner)

      search(" ")
      expect(response.status).to eq(400)

      search("target", Fabricate(:private_message_topic))
      expect(response.status).to eq(404)
    end

    context "with only category-scoped groups" do
      before { SiteSetting.assign_allowed_on_groups = "" }

      it "finds members of groups scoped to the target's category" do
        scoped_group = Fabricate(:group, members_visibility_level: Group.visibility_levels[:owners])
        scoped_group.add(target_carol)
        allow_group_to_assign_in_category(topic.category, scoped_group)
        sign_in(admin)

        search("target_carol")
        expect(usernames).to contain_exactly(target_carol.username)

        search("target_carol", post)
        expect(usernames).to contain_exactly(target_carol.username)

        search("target_carol", Fabricate(:topic, category: Fabricate(:category)))
        expect(usernames).to be_empty
      end

      it "finds what the assigner can assign anywhere when there is no target" do
        own_group = Fabricate(:group)
        own_group.add(assigner)
        own_group.add(target_carol)
        allow_group_to_assign_in_category(Fabricate(:category), own_group)
        allow_group_to_assign_in_category(Fabricate(:category), team_b)

        sign_in(assigner)
        search("target", nil)
        expect(usernames).to contain_exactly(target_carol.username, target_admin.username)

        search("team", nil)
        expect(group_names).to contain_exactly(team_a.name)

        sign_in(admin)
        search("target", nil)
        expect(usernames).to contain_exactly(
          target_bob.username,
          target_carol.username,
          target_admin.username,
        )
      end

      it "denies users who cannot assign the target" do
        scoped_group = Fabricate(:group)
        scoped_group.add(assigner)
        allow_group_to_assign_in_category(Fabricate(:category), scoped_group)
        sign_in(assigner)

        search("target")

        expect(response.status).to eq(403)
      end
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

    it "unassigns a topic with an API key scoped to assign -> assign" do
      category = Fabricate(:category)
      topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: category) }
      api_key = Fabricate(:api_key, user: admin)
      Fabricate(:api_key_scope, resource: "assign", action: "assign", api_key_id: api_key.id)
      Fabricate(:topic_assignment, target: topic, assigned_to: admin, assigned_by_user: admin)

      put "/assign/unassign.json",
          headers: {
            "HTTP_API_KEY" => api_key.key,
            "HTTP_API_USERNAME" => admin.username,
          },
          params: {
            target_id: topic.id,
            target_type: "Topic",
          }

      expect(response.status).to eq(200)
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
      assign_allowed_group.add(allowed_user)

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
      assign_allowed_group.add(allowed_user)

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

    it "returns a 400 when neither a username nor a group name is given" do
      put "/assign/assign.json", params: { target_id: post.topic_id, target_type: "Topic" }

      expect(response.status).to eq(400)
      expect(post.topic.reload.assignment).to be_nil
    end

    it "rejects assignment notes longer than the maximum post length" do
      oversized_note = "a" * (SiteSetting.max_post_length + 1)

      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
            note: oversized_note,
          }

      expect(response.status).to eq(400)
      expect(response.body).not_to include(oversized_note)
      expect(post.topic.reload.assignment).to be_nil
      expect(post.topic.posts.pluck(:raw)).not_to include(oversized_note)
    end

    it "assigns topic with a note and a status to a user" do
      put "/assign/assign.json",
          params: {
            target_id: post.topic_id,
            target_type: "Topic",
            username: allowed_user.username,
            note: "do dis pls",
            status: "In Progress",
          }

      assignment = post.topic.reload.assignment
      expect(assignment.note).to eq("do dis pls")
      expect(assignment.status).to eq("In Progress")
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
      assign_allowed_group.add(another_user)
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
      assign_allowed_group.add(another_user)
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
      assign_allowed_group.add(another_user)
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

    it "assigns a topic with an API key scoped to assign -> assign" do
      category = Fabricate(:category)
      topic = Fabricate(:post).topic.tap { |topic| topic.update!(category: category) }
      api_key = Fabricate(:api_key, user: admin)
      Fabricate(:api_key_scope, resource: "assign", action: "assign", api_key_id: api_key.id)

      put "/assign/assign.json",
          headers: {
            "HTTP_API_KEY" => api_key.key,
            "HTTP_API_USERNAME" => admin.username,
          },
          params: {
            target_id: topic.id,
            target_type: "Topic",
            username: admin.username,
          }

      expect(response.status).to eq(200)
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
        it "does not disclose hidden name matches while filtering usernames" do
          hidden_name_member =
            Fabricate(
              :user,
              username: "opaque-assignee",
              name: "Confidential Name Token",
              groups: [allowed_group],
            )
          Fabricate(:topic_assignment, assigned_to: hidden_name_member, assigned_by_user: admin)
          SiteSetting.enable_names = false
          sign_in(allowed_user)

          get "/assign/members/#{allowed_group.name}.json",
              params: {
                filter: hidden_name_member.name,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["members"].map { |member| member["id"] }).not_to include(
            hidden_name_member.id,
          )
          expect(response.body).not_to include(hidden_name_member.name)

          get "/assign/members/#{allowed_group.name}.json",
              params: {
                filter: hidden_name_member.username,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["members"].map { |member| member["id"] }).to contain_exactly(
            hidden_name_member.id,
          )
        end

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
