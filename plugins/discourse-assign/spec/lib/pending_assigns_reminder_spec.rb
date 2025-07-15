# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

def assert_reminder_not_created
  expect { reminder.remind(user) }.not_to change { Post.count }
end

RSpec.describe PendingAssignsReminder do
  subject(:reminder) { described_class.new }

  before { SiteSetting.assign_enabled = true }

  let(:user) { Fabricate(:user) }

  it "does not create a reminder if the user has 0 assigned topics" do
    assert_reminder_not_created
  end

  it "does not create a reminder if the user only has one task" do
    post = Fabricate(:post)
    Assigner.new(post.topic, user).assign(user)

    assert_reminder_not_created
  end

  describe "when the user has multiple tasks" do
    let(:system) { Discourse.system_user }

    include_context "with group that is allowed to assign"

    before do
      add_to_assign_allowed_group(user)

      secure_category = Fabricate(:private_category, group: Fabricate(:group))

      @post1 = Fabricate(:post)
      @post2 = Fabricate(:post)
      @post2.topic.update_column(:fancy_title, nil)
      @post3 = Fabricate(:post)
      @post4 = Fabricate(:post)
      Assigner.new(@post1.topic, user).assign(user)
      Assigner.new(@post2.topic, user).assign(user)
      Assigner.new(@post3.topic, user).assign(user)
      Assigner.new(@post4.topic, user).assign(user)
      @post3.topic.trash!
      @post4.topic.update(category: secure_category)
    end

    it "creates a reminder for a particular user and sets the timestamp of the last reminder" do
      freeze_time
      reminder.remind(user)

      post = Post.last

      topic = post.topic
      expect(topic.user).to eq(system)
      expect(topic.archetype).to eq(Archetype.private_message)

      expect(topic.topic_allowed_users.pluck(:user_id)).to contain_exactly(system.id, user.id)

      expect(topic.title).to eq(I18n.t("pending_assigns_reminder.title", pending_assignments: 2))

      expect(post.raw).to include(@post1.topic.fancy_title)
      expect(post.raw).to include(@post2.topic.fancy_title)
      expect(post.raw).to_not include(@post3.topic.fancy_title)
      expect(post.raw).to_not include(@post4.topic.fancy_title)

      expect(user.reload.custom_fields[described_class::REMINDED_AT].to_datetime).to eq_time(
        DateTime.now,
      )
    end

    it "deletes previous reminders when creating a new one" do
      reminder.remind(user)
      reminder.remind(user)

      reminders_count =
        Topic
          .joins(:_custom_fields)
          .where(topic_custom_fields: { name: described_class::CUSTOM_FIELD_NAME })
          .count

      expect(reminders_count).to eq(1)
    end

    it "doesn't delete reminders from a different user" do
      reminder.remind(user)
      another_user = Fabricate(:user)
      add_to_assign_allowed_group(another_user)
      3.times do
        post = Fabricate(:post)
        Assigner.new(post.topic, user).assign(another_user)
      end

      reminder.remind(another_user)

      reminders_count =
        Topic
          .joins(:_custom_fields)
          .where(topic_custom_fields: { name: described_class::CUSTOM_FIELD_NAME })
          .count

      expect(reminders_count).to eq(2)
    end

    it "doesn't delete reminders if they have replies" do
      reminder.remind(user)
      Fabricate(:post, topic: Topic.last)
      reminder.remind(user)

      reminders_count =
        Topic
          .joins(:_custom_fields)
          .where(topic_custom_fields: { name: described_class::CUSTOM_FIELD_NAME })
          .count

      expect(reminders_count).to eq(2)
    end

    it "doesn't leak assigned topics that were moved to PM" do
      # we already add a fail to assign when the assigned user cannot view the pm
      # so we don't need to test that here
      # but if we move a topic to a PM that the user can't see, we should not
      # include it in the reminder
      post = Fabricate(:post)
      Assigner.new(post.topic, user).assign(user)
      post.topic.update(archetype: Archetype.private_message, category: nil)
      reminder.remind(user)

      post = Post.last
      topic = post.topic
      expect(topic.title).to eq(I18n.t("pending_assigns_reminder.title", pending_assignments: 2))
      expect(post.raw).to include(@post1.topic.fancy_title)
      expect(post.raw).to include(@post2.topic.fancy_title)

      expect(post.raw).to_not include(post.topic.fancy_title)
    end

    it "reminds about PMs" do
      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, topic: pm)

      Assigner.new(pm, user).assign(user)
      reminder.remind(user)

      post = Post.last
      topic = post.topic

      expect(topic.title).to eq(I18n.t("pending_assigns_reminder.title", pending_assignments: 3))
      expect(post.raw).to include(@post1.topic.fancy_title)
      expect(post.raw).to include(@post2.topic.fancy_title)
      expect(post.raw).to include(pm.fancy_title)
    end

    it "closed topics aren't included as active assigns" do
      SiteSetting.unassign_on_close = true

      @post5 = Fabricate(:post)
      Assigner.new(@post5.topic, user).assign(user)

      reminder.remind(user)

      post = Post.last
      topic = post.topic

      expect(topic.title).to eq(I18n.t("pending_assigns_reminder.title", pending_assignments: 3))

      @post5.topic.update_status("closed", true, Discourse.system_user)
      expect(@post5.topic.closed).to eq(true)

      reminder.remind(user)

      post = Post.last
      topic = post.topic

      expect(topic.title).to eq(I18n.t("pending_assigns_reminder.title", pending_assignments: 2))
    end

    context "with assigns_reminder_assigned_topics_query modifier" do
      let(:modifier_block) { Proc.new { |query| query.where.not(id: @post1.topic_id) } }
      it "updates the query correctly" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:assigns_reminder_assigned_topics_query, &modifier_block)
        topics = reminder.send(:assigned_topics, user, order: :asc)
        expect(topics).not_to include(@post1.topic)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :assigns_reminder_assigned_topics_query,
          &modifier_block
        )
      end
    end

    context "with assigned_count_for_user_query modifier" do
      let(:modifier_block) { Proc.new { |query, user| query.where.not(assigned_to_id: user.id) } }
      it "updates the query correctly" do
        expect(reminder.send(:assigned_count_for, user)).to eq(2)

        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:assigned_count_for_user_query, &modifier_block)
        expect(reminder.send(:assigned_count_for, user)).to eq(0)
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :assigned_count_for_user_query,
          &modifier_block
        )
      end
    end
  end
end
