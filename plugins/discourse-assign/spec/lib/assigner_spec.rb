# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assigner do
  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_assign_status = true
  end

  let(:assign_allowed_group) { Group.find_by(name: "staff") }
  let(:pm_post) { Fabricate(:private_message_post) }
  let(:pm) { pm_post.topic }

  describe "assigning and unassigning" do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }
    let(:secure_category) { Fabricate(:private_category, group: Fabricate(:group)) }
    let(:secure_topic) { Fabricate(:post).topic.tap { |t| t.update(category: secure_category) } }
    let(:moderator) { Fabricate(:moderator) }
    let(:moderator_2) { Fabricate(:moderator) }
    let(:admin) { Fabricate(:admin) }
    let(:assigner) { described_class.new(topic, moderator_2) }
    let(:assigner_self) { described_class.new(topic, moderator) }

    it "can assign and unassign correctly" do
      expect_enqueued_with(job: :assign_notification) { assigner.assign(moderator) }

      expect(TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics).to eq(
        [topic],
      )

      expect(TopicUser.find_by(user: moderator).notification_level).to eq(
        TopicUser.notification_levels[:watching],
      )

      expect_enqueued_with(job: :unassign_notification) { assigner.unassign }

      expect(TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics).to eq([])

      expect(TopicUser.find_by(user: moderator).notification_level).to eq(
        TopicUser.notification_levels[:watching],
      )
    end

    describe "when user watchs topic when assigned" do
      before { moderator.user_option.watch_topic_when_assigned! }

      it "respects 'when assigned' user preference" do
        expect(TopicUser.find_by(user: moderator)).to be(nil)

        assigner.assign(moderator)

        expect(TopicUser.find_by(user: moderator).notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )
      end
    end

    describe "when user tracks topic when assigned" do
      before { moderator.user_option.track_topic_when_assigned! }

      it "respects 'when assigned' user preference" do
        expect(TopicUser.find_by(user: moderator)).to be(nil)

        assigner.assign(moderator)

        expect(TopicUser.find_by(user: moderator).notification_level).to eq(
          TopicUser.notification_levels[:tracking],
        )
      end
    end

    describe "when user wants to do nothing when assigned" do
      before { moderator.user_option.do_nothing_when_assigned! }

      it "respects 'when assigned' user preference" do
        expect(TopicUser.find_by(user: moderator)).to be(nil)

        assigner.assign(moderator)

        expect(TopicUser.find_by(user: moderator)).to be(nil)
      end
    end

    it "deletes notification for original assignee when reassigning" do
      Jobs.run_immediately!

      expect { described_class.new(topic, admin).assign(moderator) }.to change {
        moderator.notifications.count
      }.by(1)

      expect { described_class.new(topic, admin).assign(moderator_2) }.to change {
        moderator.notifications.count
      }.by(-1).and change { moderator_2.notifications.count }.by(1)
    end

    it "can assign with note" do
      assigner.assign(moderator, note: "tomtom best mom")

      expect(topic.assignment.note).to eq "tomtom best mom"
    end

    it "assign with note adds moderator post with note" do
      expect { assigner.assign(moderator, note: "tomtom best mom") }.to change {
        topic.posts.count
      }.by(1)
      expect(topic.posts.last.raw).to eq "tomtom best mom"
    end

    it "can assign with status" do
      assigner.assign(moderator, status: "In Progress")

      expect(topic.assignment.status).to eq "In Progress"
    end

    it "publishes topic assignment after assign and unassign" do
      messages =
        MessageBus.track_publish("/staff/topic-assignment") do
          assigner = described_class.new(topic, moderator_2)
          assigner.assign(moderator, note: "tomtom best mom", status: "In Progress")
          assigner.unassign
        end

      expect(messages[0].channel).to eq "/staff/topic-assignment"
      expect(messages[0].data).to include(
        {
          type: "assigned",
          topic_id: topic.id,
          post_id: false,
          post_number: false,
          assigned_type: "User",
          assigned_to: BasicUserSerializer.new(moderator, scope: Guardian.new, root: false).as_json,
          assignment_note: "tomtom best mom",
          assignment_status: "In Progress",
        },
      )

      expect(messages[1].channel).to eq "/staff/topic-assignment"
      expect(messages[1].data).to include(
        {
          type: "unassigned",
          topic_id: topic.id,
          post_id: false,
          post_number: false,
          assigned_type: "User",
          assignment_note: nil,
          assignment_status: nil,
        },
      )
    end

    it "does not update notification level if already watching" do
      TopicUser.change(
        moderator.id,
        topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      expect do assigner_self.assign(moderator) end.to_not change {
        TopicUser.last.notifications_reason_id
      }
    end

    it "does not update notification level when unassigned" do
      assigner.assign(moderator)

      expect(TopicUser.find_by(user: moderator).notification_level).to eq(
        TopicUser.notification_levels[:watching],
      )

      assigner.unassign

      expect(TopicUser.find_by(user: moderator, topic: topic).notification_level).to eq(
        TopicUser.notification_levels[:watching],
      )
    end

    context "when assigns_by_staff_mention is set to true" do
      let(:system_user) { Discourse.system_user }
      let(:moderator) { Fabricate(:admin, username: "modi") }
      let(:post) { Fabricate(:post, raw: "Hey you @system, stay unassigned", user: moderator) }
      let(:topic) { post.topic }

      before do
        SiteSetting.assigns_by_staff_mention = true
        SiteSetting.assign_other_regex = "\\byour (list|todo)\\b"
      end

      it "doesn't assign system user" do
        described_class.auto_assign(post)

        expect(topic.assignment).to eq(nil)
      end

      it "assigns first mentioned staff user after system user" do
        post.update(raw: "Don't assign @system. @modi, can you add this to your list?")
        described_class.auto_assign(post)

        expect(topic.assignment.assigned_to_id).to eq(moderator.id)
      end
    end

    it "doesn't assign the same user more than once" do
      SiteSetting.assign_mailer = AssignMailer.levels[:always]
      another_mod = Fabricate(:moderator)

      Email::Sender.any_instance.expects(:send).once
      expect(assigned_to?(moderator)).to eq(true)

      Email::Sender.any_instance.expects(:send).never
      expect(assigned_to?(moderator)).to eq(false)

      Email::Sender.any_instance.expects(:send).once
      expect(assigned_to?(another_mod)).to eq(true)
    end

    def assigned_to?(assignee)
      assigner.assign(assignee).fetch(:success)
    end

    describe "forbidden reasons" do
      it "doesn't assign if the topic has more than 5 assignments" do
        other_post = nil

        status = described_class.new(topic, admin).assign(Fabricate(:moderator))
        expect(status[:success]).to eq(true)

        # Assign many posts to reach the limit
        1.upto(described_class::ASSIGNMENTS_PER_TOPIC_LIMIT - 1) do
          other_post = Fabricate(:post, topic: topic)
          user = Fabricate(:moderator)
          status = described_class.new(other_post, admin).assign(user)
          expect(status[:success]).to eq(true)
        end

        # Assigning one more post is not allowed
        post = Fabricate(:post, topic: topic)
        status = described_class.new(post, admin).assign(moderator)
        expect(status[:success]).to eq(false)
        expect(status[:reason]).to eq(:too_many_assigns_for_topic)

        # Allows to reassign Topic
        status = described_class.new(topic, admin).assign(Fabricate(:moderator))
        expect(status[:success]).to eq(true)

        # Delete a post to mark the assignment as inactive
        PostDestroyer.new(admin, other_post).destroy

        # Try assigning again
        status = described_class.new(post, admin).assign(moderator)
        expect(status[:success]).to eq(true)
      end

      it "doesn't assign if the user has too many assigned topics" do
        SiteSetting.max_assigned_topics = 1
        another_post = Fabricate(:post)
        assigner.assign(moderator)

        second_assign = described_class.new(another_post.topic, moderator_2).assign(moderator)

        expect(second_assign[:success]).to eq(false)
        expect(second_assign[:reason]).to eq(:too_many_assigns)
      end

      it "doesn't enforce the limit when self-assigning" do
        SiteSetting.max_assigned_topics = 1
        another_post = Fabricate(:post)
        assigner.assign(moderator)

        second_assign = described_class.new(another_post.topic, moderator).assign(moderator)

        expect(second_assign[:success]).to eq(true)
      end

      it "doesn't count self-assigns when enforcing the limit" do
        SiteSetting.max_assigned_topics = 1
        another_post = Fabricate(:post)

        first_assign = assigner.assign(moderator)

        # reached limit so stop
        second_assign = described_class.new(Fabricate(:topic), moderator_2).assign(moderator)

        # self assign has a bypass
        third_assign = described_class.new(another_post.topic, moderator).assign(moderator)

        expect(first_assign[:success]).to eq(true)
        expect(second_assign[:success]).to eq(false)
        expect(third_assign[:success]).to eq(true)
      end

      it "doesn't count inactive assigns when enforcing the limit" do
        SiteSetting.max_assigned_topics = 1
        SiteSetting.unassign_on_close = true
        another_post = Fabricate(:post)

        first_assign = assigner.assign(moderator)
        topic.update_status("closed", true, Discourse.system_user)

        second_assign = described_class.new(another_post.topic, moderator_2).assign(moderator)

        expect(first_assign[:success]).to eq(true)
        expect(second_assign[:success]).to eq(true)
      end

      it "reassigns a post even when at the assignments limit" do
        posts =
          (described_class::ASSIGNMENTS_PER_TOPIC_LIMIT).times.map do
            Fabricate(:post, topic: topic)
          end

        posts.each do |post|
          user = Fabricate(:moderator)
          described_class.new(post, admin).assign(user)
        end

        status = described_class.new(posts.first, admin).assign(Fabricate(:moderator))
        expect(status[:success]).to eq(true)
      end

      context "when 'allow_self_reassign' is false" do
        subject(:assign) do
          assigner.assign(moderator, note: other_note, allow_self_reassign: self_reassign)
        end

        let(:self_reassign) { false }
        let(:assigner) { described_class.new(topic, moderator_2) }
        let(:note) { "note me down" }

        before { assigner.assign(moderator, note: note) }

        context "when the assigned user and the note is the same" do
          let(:other_note) { note }

          it "fails to assign" do
            expect(assign).to match(success: false, reason: :already_assigned)
          end
        end

        context "when the assigned user is the same but the note is different" do
          let(:other_note) { "note me down again" }

          it "allows assignment" do
            expect(assign).to match(success: true)
          end
        end
      end

      context "when 'allow_self_reassign' is true" do
        subject(:assign) { assigner.assign(moderator, allow_self_reassign: self_reassign) }

        let(:self_reassign) { true }
        let(:assigner) { described_class.new(topic, moderator_2) }

        context "when the assigned user is the same" do
          before { assigner.assign(moderator) }

          it "allows assignment" do
            expect(assign).to match(success: true)
          end
        end
      end

      it "fails to assign when the assigned user cannot view the pm" do
        assign = described_class.new(pm, moderator_2).assign(moderator)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_assignee_not_pm_participant)
      end

      it "fails to assign when the assigned admin cannot view the pm" do
        assign = described_class.new(pm, moderator_2).assign(admin)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_assignee_not_pm_participant)
      end

      it "fails to assign when not all group members has access to pm" do
        assign = described_class.new(pm, moderator_2).assign(moderator.groups.first)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_group_assignee_not_pm_participant)

        # even when admin
        assign = described_class.new(pm, moderator_2).assign(admin.groups.first)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_group_assignee_not_pm_participant)
      end

      it "fails to assign when the assigned user cannot view the topic" do
        assign = described_class.new(secure_topic, moderator_2).assign(moderator)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_assignee_cant_see_topic)
      end

      it "fails to assign when the not all group members can view the topic" do
        assign = described_class.new(secure_topic, moderator_2).assign(moderator.groups.first)

        expect(assign[:success]).to eq(false)
        expect(assign[:reason]).to eq(:forbidden_group_assignee_cant_see_topic)
      end
    end

    it "assigns the PM to the moderator when it's included in the list of allowed users" do
      pm.allowed_users << moderator

      assign = described_class.new(pm, moderator_2).assign(moderator)

      expect(assign[:success]).to eq(true)
    end

    it "assigns the PM to the moderator when it's a member of an allowed group" do
      pm.allowed_groups << assign_allowed_group

      assign = described_class.new(pm, moderator_2).assign(moderator)

      expect(assign[:success]).to eq(true)
    end

    it "triggers error for incorrect type" do
      expect do
        described_class.new(secure_category, moderator).assign(moderator)
      end.to raise_error(Discourse::InvalidParameters)
    end

    describe "updating notes" do
      it "does not recreate assignment if no assignee change" do
        assigner.assign(moderator)

        expect do assigner.assign(moderator, note: "new notes!") end.to_not change {
          Assignment.last.id
        }
      end

      it "updates notes" do
        assigner.assign(moderator)

        assigner.assign(moderator, note: "new notes!")

        expect(Assignment.last.note).to eq "new notes!"
      end

      it "queues notification" do
        assigner.assign(moderator)

        expect_enqueued_with(job: :assign_notification) do
          assigner.assign(moderator, note: "new notes!")
        end
      end

      it "publishes topic assignment with note" do
        assigner.assign(moderator)

        messages =
          MessageBus.track_publish("/staff/topic-assignment") do
            assigner = described_class.new(topic, moderator_2)
            assigner.assign(moderator, note: "new notes!")
          end

        expect(messages[0].channel).to eq "/staff/topic-assignment"
        expect(messages[0].data).to include(
          {
            type: "assigned",
            topic_id: topic.id,
            post_id: false,
            post_number: false,
            assigned_type: "User",
            assigned_to:
              BasicUserSerializer.new(moderator, scope: Guardian.new, root: false).as_json,
            assignment_note: "new notes!",
          },
        )
      end

      it "adds a note_change small action post" do
        assigner.assign(moderator)

        assigner.assign(moderator, note: "new notes!")

        small_action_post = topic.posts.last
        expect(small_action_post.action_code).to eq "note_change"
      end
    end

    describe "updating status" do
      it "does not recreate assignment if no assignee change" do
        assigner.assign(moderator)

        expect do assigner.assign(moderator, status: "Done") end.to_not change {
          Assignment.last.id
        }
      end

      it "updates status" do
        assigner.assign(moderator)

        assigner.assign(moderator, status: "Done")

        expect(Assignment.last.status).to eq "Done"
      end

      it "queues notification" do
        assigner.assign(moderator)

        expect(job_enqueued?(job: :assign_notification)).to eq(true)
        expect_enqueued_with(job: :assign_notification) do
          assigner.assign(moderator, status: "Done")
        end
      end

      it "does not queue notification if should_notify is set to false" do
        assigner.assign(moderator, status: "Done", should_notify: false)
        expect(job_enqueued?(job: :assign_notification)).to eq(false)
      end

      it "publishes topic assignment with note" do
        assigner.assign(moderator)

        messages =
          MessageBus.track_publish("/staff/topic-assignment") do
            assigner = described_class.new(topic, moderator_2)
            assigner.assign(moderator, status: "Done")
          end

        expect(messages[0].channel).to eq "/staff/topic-assignment"
        expect(messages[0].data).to include(
          {
            type: "assigned",
            topic_id: topic.id,
            post_id: false,
            post_number: false,
            assigned_type: "User",
            assigned_to:
              BasicUserSerializer.new(moderator, scope: Guardian.new, root: false).as_json,
            assignment_status: "Done",
          },
        )
      end

      it "adds a note_change small action post" do
        assigner.assign(moderator)

        assigner.assign(moderator, status: "Done")

        small_action_post = topic.posts.last
        expect(small_action_post.action_code).to eq "status_change"
      end
    end

    describe "updating note and status at the same time" do
      it "adds a note_change small action post" do
        assigner.assign(moderator)

        assigner.assign(moderator, note: "This is a note!", status: "Done")

        small_action_post = topic.posts.last
        expect(small_action_post.action_code).to eq "details_change"
      end
    end
  end

  describe "assign_self_regex" do
    fab!(:me) { Fabricate(:admin) }
    fab!(:op) { Fabricate(:post) }
    fab!(:reply) do
      Fabricate(:post, topic: op.topic, user: me, raw: "Will fix. Added to my list ;)")
    end

    before do
      SiteSetting.assigns_by_staff_mention = true
      SiteSetting.assign_self_regex = "\\bmy list\\b"
    end

    it "automatically assigns to myself" do
      expect(described_class.auto_assign(reply)).to eq(success: true)
      expect(op.topic.assignment.assigned_to_id).to eq(me.id)
      expect(op.topic.assignment.assigned_by_user_id).to eq(me.id)
    end

    it "does not automatically assign to myself" do
      admin = Fabricate(:admin)
      raw = <<~MD
        [quote]
        Will fix. Added to my list ;)
        [/quote]

        `my list`

        ```text
        my list
        ```

            my list

        Excellent :clap: Can't wait!
      MD

      another_reply = Fabricate(:post, topic: op.topic, user: admin, raw: raw)
      expect(described_class.auto_assign(another_reply)).to eq(nil)
    end
  end

  describe "assign_other_regex" do
    fab!(:me) { Fabricate(:admin) }
    fab!(:other) { Fabricate(:admin) }
    fab!(:op) { Fabricate(:post) }
    fab!(:reply) do
      Fabricate(
        :post,
        topic: op.topic,
        user: me,
        raw: "can you add this to your list, @#{other.username}",
      )
    end

    before do
      SiteSetting.assigns_by_staff_mention = true
      SiteSetting.assign_other_regex = "\\byour (list|todo)\\b"
    end

    it "automatically assigns to other" do
      expect(described_class.auto_assign(reply)).to eq(success: true)
      expect(op.topic.assignment.assigned_to_id).to eq(other.id)
      expect(op.topic.assignment.assigned_by_user_id).to eq(me.id)
    end
  end

  describe "unassign_on_close" do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }
    let(:moderator) { Fabricate(:moderator) }

    context "with topic" do
      let(:assigner) { described_class.new(topic, moderator) }

      before do
        SiteSetting.unassign_on_close = true
        assigner.assign(moderator)
      end

      it "unassigns on topic closed" do
        topic.update_status("closed", true, moderator)
        expect(
          TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics,
        ).to be_blank
      end

      it "unassigns on topic autoclosed" do
        topic.update_status("autoclosed", true, moderator)
        expect(
          TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics,
        ).to be_blank
      end

      it "does not unassign on topic open" do
        topic.update_status("closed", false, moderator)
        expect(TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics).to eq(
          [topic],
        )
      end

      it "does not unassign on automatic topic open" do
        topic.update_status("autoclosed", false, moderator)
        expect(TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics).to eq(
          [topic],
        )
      end
    end

    context "with post" do
      let(:post_2) { Fabricate(:post, topic: topic) }
      let(:assigner) { described_class.new(post_2, moderator) }
      let(:post_3) { Fabricate(:post, topic: topic) }
      let(:assigner_2) { described_class.new(post_3, moderator) }

      before do
        SiteSetting.unassign_on_close = true
        SiteSetting.reassign_on_open = true

        assigner.assign(moderator)
      end

      it "deactivates post assignments when topic is closed" do
        assigner.assign(moderator)

        expect(post_2.assignment.active).to be true

        topic.update_status("closed", true, moderator)
        expect(post_2.assignment.reload.active).to be false
      end

      it "deactivates post assignments when post is deleted and activate when recovered" do
        assigner.assign(moderator)

        expect(post_2.assignment.active).to be true

        PostDestroyer.new(moderator, post_2).destroy
        expect(post_2.assignment.reload.active).to be false

        PostDestroyer.new(moderator, post_2).recover
        expect(post_2.assignment.reload.active).to be true
      end

      it "deletes post small action for deleted post" do
        assigner.assign(moderator)
        small_action_post = PostCustomField.where(name: "action_code_post_id").first.post

        PostDestroyer.new(moderator, post_2).destroy
        expect { small_action_post.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "deletes post successfully when small action is already deleted" do
        assigner_2.assign(moderator)
        small_action_post = PostCustomField.where(name: "action_code_post_id").first.post

        PostDestroyer.new(moderator, small_action_post).destroy
        PostDestroyer.new(moderator, post_3).destroy

        expect(small_action_post.reload.deleted_at).to be_present
        expect(post_3.reload.deleted_at).to be_present
      end
    end
  end

  describe "reassign_on_open" do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }
    let(:moderator) { Fabricate(:moderator) }

    describe "topic" do
      let(:assigner) { described_class.new(topic, moderator) }

      before do
        SiteSetting.unassign_on_close = true
        SiteSetting.reassign_on_open = true
        assigner.assign(moderator)
      end

      it "reassigns on topic open" do
        topic.update_status("closed", true, moderator)
        expect(
          TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics,
        ).to be_blank

        topic.update_status("closed", false, moderator)
        expect(TopicQuery.new(moderator, assigned: moderator.username).list_latest.topics).to eq(
          [topic],
        )
      end
    end

    context "with post" do
      let(:post_2) { Fabricate(:post, topic: topic) }
      let(:assigner) { described_class.new(post_2, moderator) }

      before do
        SiteSetting.unassign_on_close = true
        SiteSetting.reassign_on_open = true

        assigner.assign(moderator)
      end

      it "reassigns post on topic open" do
        assigner.assign(moderator)

        expect(post_2.assignment.active).to be true

        topic.update_status("closed", true, moderator)
        expect(post_2.assignment.reload.active).to be false

        topic.update_status("closed", false, moderator)
        expect(post_2.assignment.reload.active).to be true
      end
    end
  end

  describe "invite_on_assign" do
    let(:admin) { Fabricate(:admin) }
    let(:topic) { Fabricate(:private_message_topic) }
    let(:post) { Fabricate(:post, topic: topic) }
    let(:assigner) { described_class.new(topic, admin) }

    before do
      SiteSetting.invite_on_assign = true
      post
    end

    it "invites user to the PM" do
      user = Fabricate(:user)
      assigner.assign(user)
      expect(topic.allowed_users).to include(user)
    end

    it "doesn't invite user to the PM when already a member of an allowed group" do
      user = Fabricate(:user)
      assign_allowed_group.add(user)
      topic.allowed_groups << assign_allowed_group
      assigner.assign(user)
      expect(topic.allowed_users).not_to include(user)
    end

    it "invites group to the PM and notifies users" do
      group =
        Fabricate(
          :group,
          assignable_level: Group::ALIAS_LEVELS[:only_admins],
          messageable_level: Group::ALIAS_LEVELS[:only_admins],
        )
      group.add(Fabricate(:user))

      Notification.delete_all
      Jobs.run_immediately!

      assigner.assign(group)
      expect(topic.allowed_groups).to include(group)
      expect(Notification.count).to be > 0
    end

    it "invites group to the PM and does not notifies users if should_notify is false" do
      group =
        Fabricate(
          :group,
          assignable_level: Group::ALIAS_LEVELS[:only_admins],
          messageable_level: Group::ALIAS_LEVELS[:only_admins],
        )
      group.add(Fabricate(:user))

      Notification.delete_all
      Jobs.run_immediately!

      assigner.assign(group, should_notify: false)
      expect(topic.allowed_groups).to include(group)
      expect(Notification.count).to eq(0)
      expect(SilencedAssignment.count).to eq(1)

      group.add(Fabricate(:user))
      expect(Notification.count).to eq(0) # no one is ever notified about this assignment
    end

    it "doesn't invite group if all members have access to the PM already" do
      user1, user2, user3 = 3.times.collect { Fabricate(:user) }
      group1, group2, group3 =
        3.times.collect do
          Fabricate(
            :group,
            assignable_level: Group::ALIAS_LEVELS[:only_admins],
            messageable_level: Group::ALIAS_LEVELS[:only_admins],
          )
        end
      group1.add(user1)
      group1.add(user3)
      group2.add(user2)
      group2.add(user3)
      group3.add(user3)
      topic.allowed_groups << group1

      assigner.assign(group2)
      assigner.assign(group3)

      expect(topic.allowed_groups).to match_array([group1, group2])
    end

    it "doesn't invite group to the PM if it's not messageable" do
      group =
        Fabricate(
          :group,
          assignable_level: Group::ALIAS_LEVELS[:only_admins],
          messageable_level: Group::ALIAS_LEVELS[:nobody],
        )
      group.add(Fabricate(:user))
      expect { assigner.assign(group) }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe "assign_emailer" do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }
    let(:moderator) { Fabricate(:moderator) }
    let(:moderator_2) { Fabricate(:moderator) }

    it "send an email if set to 'always'" do
      SiteSetting.assign_mailer = AssignMailer.levels[:always]

      expect { described_class.new(topic, moderator).assign(moderator) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    it "doesn't send an email if assignee is a group" do
      SiteSetting.assign_mailer = AssignMailer.levels[:always]

      expect { described_class.new(topic, moderator).assign(assign_allowed_group) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "doesn't send an email if the assigner and assignee are not different" do
      SiteSetting.assign_mailer = AssignMailer.levels[:different_users]

      expect { described_class.new(topic, moderator).assign(moderator_2) }.to change {
        ActionMailer::Base.deliveries.size
      }.by(1)
    end

    it "doesn't send an email if the assigner and assignee are not different" do
      SiteSetting.assign_mailer = AssignMailer.levels[:different_users]

      expect { described_class.new(topic, moderator).assign(moderator) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end

    it "doesn't send an email" do
      SiteSetting.assign_mailer = AssignMailer.levels[:never]

      expect { described_class.new(topic, moderator).assign(moderator_2) }.not_to change {
        ActionMailer::Base.deliveries.size
      }
    end
  end
end
