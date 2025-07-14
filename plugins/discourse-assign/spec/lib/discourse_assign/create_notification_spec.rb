# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAssign::CreateNotification do
  describe ".call" do
    subject(:create_notification) do
      described_class.call(assignment: assignment, user: user, mark_as_read: mark_as_read)
    end

    let(:assignment) { Fabricate(:topic_assignment, topic: post.topic, assigned_to: assigned_to) }
    let(:post) { Fabricate(:post) }
    let(:mark_as_read) { false }
    let(:alerter) { stub_everything("alerter").responds_like_instance_of(PostAlerter) }

    before { PostAlerter.stubs(:new).returns(alerter) }

    context "when assigned to a single user" do
      let(:assigned_to) { Fabricate(:user) }
      let(:user) { assigned_to }

      it "publishes topic tracking state" do
        Assigner.expects(:publish_topic_tracking_state).with(assignment.topic, user.id)
        create_notification
      end

      context "when topic is not found" do
        before { assignment.topic = nil }

        it "does not publish topic tracking state" do
          Assigner.expects(:publish_topic_tracking_state).never
          create_notification
        end

        it "does not create a notification alert" do
          alerter.expects(:create_notification_alert).never
          create_notification
        end
      end

      context "when `mark_as_read` is false" do
        let(:excerpt) do
          I18n.t(
            "discourse_assign.topic_assigned_excerpt",
            title: post.topic.title,
            group: user.name,
            locale: user.effective_locale,
          )
        end

        it "creates a notification alert" do
          alerter.expects(:create_notification_alert).with(
            user: user,
            post: post,
            username: assignment.assigned_by_user.username,
            notification_type: Notification.types[:assigned],
            excerpt: excerpt,
          )
          create_notification
        end
      end

      context "when `mark_as_read` is true" do
        let(:mark_as_read) { true }

        it "does not create a notification alert" do
          alerter.expects(:create_notification_alert).never
          create_notification
        end
      end

      it "creates a notification" do
        expect { create_notification }.to change { Notification.count }.by(1)
        expect(Notification.assigned.last).to have_attributes(
          created_at: assignment.created_at,
          updated_at: assignment.updated_at,
          user: user,
          topic: post.topic,
          post_number: post.post_number,
          high_priority: true,
          read: mark_as_read,
          data_hash: {
            message: "discourse_assign.assign_notification",
            display_username: assignment.assigned_by_user.username,
            topic_title: post.topic.title,
            assignment_id: assignment.id,
          },
        )
      end
    end

    context "when assigned to a group" do
      let(:assigned_to) { Fabricate(:group) }
      let(:user) { Fabricate(:user) }

      before { assigned_to.users << user }

      it "publishes topic tracking state" do
        Assigner.expects(:publish_topic_tracking_state).with(assignment.topic, user.id)
        create_notification
      end

      context "when `mark_as_read` is false" do
        let(:excerpt) do
          I18n.t(
            "discourse_assign.topic_group_assigned_excerpt",
            title: post.topic.title,
            group: assigned_to.name,
            locale: user.effective_locale,
          )
        end

        it "creates a notification alert" do
          alerter.expects(:create_notification_alert).with(
            user: user,
            post: post,
            username: assignment.assigned_by_user.username,
            notification_type: Notification.types[:assigned],
            excerpt: excerpt,
          )
          create_notification
        end
      end

      context "when `mark_as_read` is true" do
        let(:mark_as_read) { true }

        it "does not create a notification alert" do
          alerter.expects(:create_notification_alert).never
          create_notification
        end
      end

      it "creates a notification" do
        expect { create_notification }.to change { Notification.count }.by(1)
        expect(Notification.assigned.last).to have_attributes(
          created_at: assignment.created_at,
          updated_at: assignment.updated_at,
          user: user,
          topic: post.topic,
          post_number: post.post_number,
          high_priority: true,
          read: mark_as_read,
          data_hash: {
            message: "discourse_assign.assign_group_notification",
            display_username: assigned_to.name,
            topic_title: post.topic.title,
            assignment_id: assignment.id,
          },
        )
      end
    end
  end
end
