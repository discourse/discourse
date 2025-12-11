# frozen_string_literal: true

RSpec.describe TopicsBulkAction do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }

  describe "dismiss_topics" do
    fab!(:user) { Fabricate(:user, created_at: 1.day.ago, refresh_auto_groups: true) }
    fab!(:category)
    fab!(:topic2) { Fabricate(:topic, category: category, created_at: 60.minutes.ago) }
    fab!(:topic3) { Fabricate(:topic, category: category, created_at: 120.minutes.ago) }

    before { topic.destroy! }

    it "dismisses private messages" do
      pm = Fabricate(:private_message_topic, recipient: user)

      TopicsBulkAction.new(user, [pm.id], type: "dismiss_topics").perform!

      expect(DismissedTopicUser.exists?(topic: pm)).to eq(true)
    end

    it "dismisses two topics" do
      expect {
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      }.to change { DismissedTopicUser.count }.by(2)
    end

    it "returns dismissed topic ids" do
      expect(
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!.sort,
      ).to match_array([topic2.id, topic3.id])
    end

    it "respects max_new_topics limit" do
      SiteSetting.max_new_topics = 1
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic2.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end

    it "respects seen topics" do
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: 1)
      Fabricate(:topic_user, user: user, topic: topic3, last_read_post_number: 1)
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.not_to change { DismissedTopicUser.count }
    end

    it "dismisses when topic user without last_read_post_number" do
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: nil)
      Fabricate(:topic_user, user: user, topic: topic3, last_read_post_number: nil)
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(2)
    end

    it "respects new_topic_duration_minutes" do
      user.user_option.update!(new_topic_duration_minutes: 70)

      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic2.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end

    it "doesn't dismiss topics the user can't see" do
      group = Fabricate(:group)
      private_category = Fabricate(:private_category, group: group)
      topic2.update!(category_id: private_category.id)

      expect do
        TopicsBulkAction.new(user, [topic2.id, topic3.id], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([topic3.id])

      group.add(user)

      expect do
        TopicsBulkAction.new(user, [topic2.id, topic3.id], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to contain_exactly(
        topic2.id,
        topic3.id,
      )
    end
  end

  describe "dismiss_posts" do
    it "dismisses posts" do
      post1 = create_post
      post2 = create_post(topic_id: post1.topic_id)
      create_post(topic_id: post1.topic_id)

      PostDestroyer.new(Fabricate(:admin), post2).destroy

      TopicTrackingState.expects(:publish_dismiss_new_posts).with(
        post1.user_id,
        topic_ids: [post1.topic_id],
      )

      TopicsBulkAction.new(post1.user, [post1.topic_id], type: "dismiss_posts").perform!

      tu = TopicUser.find_by(user_id: post1.user_id, topic_id: post1.topic_id)

      expect(tu.last_read_post_number).to eq(3)
    end

    context "when the user is staff" do
      fab!(:user, :admin)

      context "when the highest_staff_post_number is > highest_post_number for a topic (e.g. whisper is last post)" do
        it "dismisses posts" do
          SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
          post1 = create_post(user: user)
          create_post(topic_id: post1.topic_id)
          create_post(topic_id: post1.topic_id)

          PostCreator.new(
            user,
            topic_id: post1.topic.id,
            post_type: Post.types[:whisper],
            raw: "this is a whispered reply",
          ).create

          TopicsBulkAction.new(user, [post1.topic_id], type: "dismiss_posts").perform!

          tu = TopicUser.find_by(user_id: user.id, topic_id: post1.topic_id)

          expect(tu.last_read_post_number).to eq(4)
        end
      end
    end
  end

  describe "invalid operation" do
    let(:user) { Fabricate.build(:user) }

    it "raises an error with an invalid operation" do
      tba = TopicsBulkAction.new(user, [1], type: "rm_root")
      expect { tba.perform! }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "change_category" do
    fab!(:category)
    fab!(:first_post) { Fabricate(:post, topic: topic) }

    describe "silent option" do
      fab!(:topic_watcher, :user)
      fab!(:category_watcher, :user)
      fab!(:admin)

      before do
        Jobs.run_immediately!
        TopicUser.change(
          topic_watcher,
          topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        CategoryUser.set_notification_level_for_category(
          category_watcher,
          CategoryUser.notification_levels[:watching_first_post],
          category.id,
        )
      end

      shared_examples "silent option suppresses topic watcher notifications" do
        it "notifies topic watchers when silent is false" do
          expect do
            TopicsBulkAction.new(
              admin,
              [topic.id],
              type: "change_category",
              category_id: category.id,
            ).perform!
          end.to change { Notification.where(user: topic_watcher).count }
        end

        it "does not notify topic watchers when silent is true" do
          expect do
            TopicsBulkAction.new(
              admin,
              [topic.id],
              type: "change_category",
              category_id: category.id,
              silent: true,
            ).perform!
          end.to not_change { Notification.where(user: topic_watcher).count }
        end
      end

      context "when create_revision_on_bulk_topic_moves is enabled" do
        SiteSetting.create_revision_on_bulk_topic_moves = true
        include_examples "silent option suppresses topic watcher notifications"
      end

      context "when create_revision_on_bulk_topic_moves is disabled" do
        SiteSetting.create_revision_on_bulk_topic_moves = false
        include_examples "silent option suppresses topic watcher notifications"

        it "notifies category watchers when silent is false" do
          expect do
            TopicsBulkAction.new(
              admin,
              [topic.id],
              type: "change_category",
              category_id: category.id,
            ).perform!
          end.to change { Notification.where(user: category_watcher).count }.by(1)

          expect(Notification.where(user: category_watcher).last.notification_type).to eq(
            Notification.types[:watching_first_post],
          )
        end

        it "does not notify category watchers when silent is true" do
          expect do
            TopicsBulkAction.new(
              admin,
              [topic.id],
              type: "change_category",
              category_id: category.id,
              silent: true,
            ).perform!
          end.to not_change { Notification.where(user: category_watcher).count }
        end
      end
    end

    context "when the user can edit the topic" do
      it "changes category and creates revision when setting enabled" do
        SiteSetting.create_revision_on_bulk_topic_moves = true
        old_category_id = topic.category_id

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_category",
            category_id: category.id,
          ).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.category).to eq(category)

        revision = topic.first_post.revisions.last
        expect(revision.modifications).to eq({ "category_id" => [old_category_id, category.id] })
      end

      it "changes category without revision when setting disabled" do
        SiteSetting.create_revision_on_bulk_topic_moves = false

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_category",
            category_id: category.id,
          ).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.category).to eq(category)
        expect(topic.first_post.revisions.last).to be_nil
      end

      it "does nothing when category stays the same" do
        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_category",
            category_id: topic.category_id,
          ).perform!

        expect(topic_ids).to be_empty
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't change the category" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        original_category = topic.category

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_category",
            category_id: category.id,
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic.reload.category).to eq(original_category)
      end
    end
  end

  describe "destroy_post_timing" do
    fab!(:first_post) { Fabricate(:post, topic: topic) }

    before { PostTiming.process_timings(topic.user, topic.id, 10, [[1, 10]]) }

    it "delegates to PostTiming.destroy_for" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: "destroy_post_timing")
      topic_ids = nil
      expect { topic_ids = tba.perform! }.to change { PostTiming.count }.by(-1)
      expect(topic_ids).to contain_exactly(topic.id)
    end
  end

  describe "delete" do
    fab!(:topic) { Fabricate(:post).topic }
    fab!(:moderator)

    it "deletes the topic" do
      tba = TopicsBulkAction.new(moderator, [topic.id], type: "delete")
      tba.perform!
      topic.reload
      expect(topic).to be_trashed
    end
  end

  describe "change_notification_level" do
    it "updates the notification level when user can see topic" do
      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "change_notification_level",
          notification_level_id: 2,
        ).perform!

      expect(topic_ids).to eq([topic.id])
      expect(TopicUser.get(topic, topic.user).notification_level).to eq(2)
    end

    it "doesn't change level when user can't see topic" do
      Guardian.any_instance.expects(:can_see?).returns(false)

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "change_notification_level",
          notification_level_id: 2,
        ).perform!

      expect(topic_ids).to eq([])
      expect(TopicUser.get(topic, topic.user)).to be_blank
    end

    ["", nil, :missing].each do |invalid_value|
      it "raises error when notification_level_id is #{invalid_value.inspect}" do
        options = { type: "change_notification_level" }
        options[:notification_level_id] = invalid_value unless invalid_value == :missing

        expect do
          TopicsBulkAction.new(topic.user, [topic.id], **options).perform!
        end.to raise_error(Discourse::InvalidParameters, /notification_level_id/)
      end
    end
  end

  %w[close archive unlist].each do |action|
    describe action do
      it "#{action}s topic when user can moderate" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)

        topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: action).perform!

        expect(topic_ids).to eq([topic.id])
        topic.reload
        case action
        when "close"
          expect(topic).to be_closed
        when "archive"
          expect(topic).to be_archived
        when "unlist"
          expect(topic).not_to be_visible
        end
      end

      it "doesn't #{action} topic when user can't moderate" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)

        topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: action).perform!

        expect(topic_ids).to be_blank
        topic.reload
        case action
        when "close"
          expect(topic).not_to be_closed
        when "archive"
          expect(topic).not_to be_archived
        when "unlist"
          expect(topic).to be_visible
        end
      end
    end
  end

  describe "reset_bump_dates" do
    it "resets bump date when user can update" do
      post_created_at = 1.day.ago
      create_post(topic_id: topic.id, created_at: post_created_at)
      topic.update!(bumped_at: 1.hour.ago)
      Guardian.any_instance.expects(:can_update_bumped_at?).returns(true)

      topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "reset_bump_dates").perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.bumped_at).to eq_time(post_created_at)
    end

    it "doesn't reset bump date when user can't update" do
      create_post(topic_id: topic.id, created_at: 1.day.ago)
      bumped_at = 1.hour.ago
      topic.update!(bumped_at: bumped_at)
      Guardian.any_instance.expects(:can_update_bumped_at?).returns(false)

      topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "reset_bump_dates").perform!

      expect(topic_ids).to eq([])
      expect(topic.reload.bumped_at).to eq_time(bumped_at)
    end
  end

  describe "change_tags" do
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      topic.tags = [tag1, tag2]
    end

    it "changes tags and creates new ones when permitted" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "change_tags",
          tags: ["newtag", tag1.name],
        ).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags.map(&:name)).to contain_exactly("newtag", tag1.name)
    end

    it "changes to existing tags only when can't create new ones" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "change_tags",
          tags: ["newtag", tag1.name],
        ).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name)
    end

    it "removes all tags with empty array" do
      topic_ids =
        TopicsBulkAction.new(topic.user, [topic.id], type: "change_tags", tags: []).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags).to be_empty
    end

    it "doesn't change tags when user can't edit topic" do
      Guardian.any_instance.expects(:can_edit?).returns(false)

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "change_tags",
          tags: ["newtag", tag1.name],
        ).perform!

      expect(topic_ids).to eq([])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
    end
  end

  describe "append_tags" do
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)
    fab!(:tag3, :tag)

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      topic.tags = [tag1, tag2]
    end

    it "appends new and existing tags when permitted" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "append_tags",
          tags: [tag1.name, tag3.name, "newtag"],
        ).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(
        tag1.name,
        tag2.name,
        tag3.name,
        "newtag",
      )
    end

    it "appends only existing tags when can't create new ones" do
      SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "append_tags",
          tags: [tag3.name, "newtag"],
        ).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name, tag3.name)
    end

    it "keeps existing tags when appending empty array" do
      topic_ids =
        TopicsBulkAction.new(topic.user, [topic.id], type: "append_tags", tags: []).perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
    end

    it "doesn't change tags when user can't edit topic" do
      Guardian.any_instance.expects(:can_edit?).returns(false)

      topic_ids =
        TopicsBulkAction.new(
          topic.user,
          [topic.id],
          type: "append_tags",
          tags: ["newtag", tag3.name],
        ).perform!

      expect(topic_ids).to eq([])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
    end
  end

  describe "remove_tags" do
    fab!(:tag1, :tag)
    fab!(:tag2, :tag)

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      TopicTag.create!(topic: topic, tag: tag1)
      TopicTag.create!(topic: topic, tag: tag2)
    end

    it "removes all tags and updates tag counts" do
      expect(tag1.reload.staff_topic_count).to eq(1)

      topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "remove_tags").perform!

      expect(topic_ids).to eq([topic.id])
      expect(topic.reload.tags).to be_empty
      expect(tag1.reload.staff_topic_count).to eq(0)
    end

    it "doesn't remove tags when user can't edit topic" do
      Guardian.any_instance.expects(:can_edit?).returns(false)

      topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "remove_tags").perform!

      expect(topic_ids).to eq([])
      expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
    end
  end
end
