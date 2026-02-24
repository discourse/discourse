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
      fab!(:admin)

      before do
        Jobs.run_immediately!
        PostActionNotifier.enable
        SiteSetting.create_revision_on_bulk_topic_moves = true
        TopicUser.change(
          Fabricate(:user),
          topic.id,
          notification_level: TopicUser.notification_levels[:watching],
        )
        CategoryUser.set_notification_level_for_category(
          Fabricate(:user),
          CategoryUser.notification_levels[:watching_first_post],
          category.id,
        )
      end

      it "does not create any notifications when silent is true" do
        expect do
          TopicsBulkAction.new(
            admin,
            [topic.id],
            type: "change_category",
            category_id: category.id,
            silent: true,
          ).perform!
        end.to not_change { Notification.count }
      end

      it "creates notifications when silent is false" do
        expect do
          TopicsBulkAction.new(
            admin,
            [topic.id],
            type: "change_category",
            category_id: category.id,
          ).perform!
        end.to change { Notification.count }
      end
    end

    context "when the user can edit the topic" do
      context "when create_revision_on_bulk_topic_moves is enabled" do
        before { SiteSetting.create_revision_on_bulk_topic_moves = true }

        it "changes category and creates revision" do
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
      end

      context "when create_revision_on_bulk_topic_moves is disabled" do
        before { SiteSetting.create_revision_on_bulk_topic_moves = false }

        it "changes category without revision" do
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

    context "when destination category does not allow the topic's tags" do
      fab!(:destination_category, :category)
      fab!(:other_tag) { Fabricate(:tag, name: "other-tag") }
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:source_category) { Fabricate(:category, tags: [restricted_tag]) }
      fab!(:admin)
      fab!(:moderator)
      fab!(:topic_with_tag) { Fabricate(:topic, category: source_category, tags: [restricted_tag]) }
      fab!(:first_post_for_tagged_topic) { Fabricate(:post, topic: topic_with_tag) }

      before { destination_category.update!(tags: [other_tag]) }

      it "allows admins to change category" do
        topic_ids =
          TopicsBulkAction.new(
            admin,
            [topic_with_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([topic_with_tag.id])
        expect(topic_with_tag.reload.category).to eq(destination_category)
        expect(topic_with_tag.tags).to contain_exactly(restricted_tag)
      end

      it "does not change category for moderators" do
        topic_ids =
          TopicsBulkAction.new(
            moderator,
            [topic_with_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_with_tag.reload.category).to eq(source_category)
      end

      it "does not change category for regular users" do
        topic_ids =
          TopicsBulkAction.new(
            topic_with_tag.user,
            [topic_with_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_with_tag.reload.category).to eq(source_category)
      end
    end

    context "when destination category has the same tag group as source" do
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:tag_group) { Fabricate(:tag_group, tags: [restricted_tag]) }
      fab!(:source_category) { Fabricate(:category, tag_groups: [tag_group]) }
      fab!(:destination_category) { Fabricate(:category, tag_groups: [tag_group]) }
      fab!(:admin)
      fab!(:topic_with_tag) { Fabricate(:topic, category: source_category, tags: [restricted_tag]) }
      fab!(:first_post_for_tagged_topic) { Fabricate(:post, topic: topic_with_tag) }

      it "changes category successfully" do
        topic_ids =
          TopicsBulkAction.new(
            admin,
            [topic_with_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([topic_with_tag.id])
        expect(topic_with_tag.reload.category).to eq(destination_category)
      end
    end

    context "when destination category has allow_global_tags enabled" do
      fab!(:global_tag) { Fabricate(:tag, name: "global-tag") }
      fab!(:source_category, :category)
      fab!(:destination_category) { Fabricate(:category, allow_global_tags: true) }
      fab!(:admin)
      fab!(:topic_with_tag) { Fabricate(:topic, category: source_category, tags: [global_tag]) }
      fab!(:first_post_for_tagged_topic) { Fabricate(:post, topic: topic_with_tag) }

      it "changes category successfully for unrestricted tags" do
        topic_ids =
          TopicsBulkAction.new(
            admin,
            [topic_with_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([topic_with_tag.id])
        expect(topic_with_tag.reload.category).to eq(destination_category)
      end
    end

    context "when destination category disallows global tags" do
      fab!(:global_tag) { Fabricate(:tag, name: "global-tag") }
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:tag_group) { Fabricate(:tag_group, tags: [restricted_tag]) }
      fab!(:source_category, :category)
      fab!(:destination_category) do
        Fabricate(:category, tag_groups: [tag_group], allow_global_tags: false)
      end
      fab!(:admin)
      fab!(:moderator)
      fab!(:topic_with_global_tag) do
        Fabricate(:topic, category: source_category, tags: [global_tag])
      end
      fab!(:first_post) { Fabricate(:post, topic: topic_with_global_tag) }

      it "allows admin to move topic with global tags" do
        topic_ids =
          TopicsBulkAction.new(
            admin,
            [topic_with_global_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([topic_with_global_tag.id])
        expect(topic_with_global_tag.reload.category).to eq(destination_category)
      end

      it "prevents moderator from moving topic with global tags" do
        topic_ids =
          TopicsBulkAction.new(
            moderator,
            [topic_with_global_tag.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_with_global_tag.reload.category).to eq(source_category)
      end
    end

    context "when tags violate one-per-topic tag group rule" do
      fab!(:tag1) { Fabricate(:tag, name: "priority-high") }
      fab!(:tag2) { Fabricate(:tag, name: "priority-low") }
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2], one_per_topic: true) }
      fab!(:source_category, :category)
      fab!(:destination_category) { Fabricate(:category, tag_groups: [tag_group]) }
      fab!(:admin)
      fab!(:moderator)
      fab!(:topic_with_conflicting_tags) do
        Fabricate(:topic, category: source_category, tags: [tag1, tag2])
      end
      fab!(:first_post) { Fabricate(:post, topic: topic_with_conflicting_tags) }

      it "allows admin to move topic with conflicting tags" do
        topic_ids =
          TopicsBulkAction.new(
            admin,
            [topic_with_conflicting_tags.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([topic_with_conflicting_tags.id])
        expect(topic_with_conflicting_tags.reload.category).to eq(destination_category)
      end

      it "prevents moderator from moving topic with conflicting tags" do
        topic_ids =
          TopicsBulkAction.new(
            moderator,
            [topic_with_conflicting_tags.id],
            type: "change_category",
            category_id: destination_category.id,
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_with_conflicting_tags.reload.category).to eq(source_category)
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

    context "when the user can edit the topic" do
      fab!(:tag3, :tag)

      it "changes tags to specified tags" do
        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_tags",
            tag_ids: [tag1.id, tag3.id],
          ).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.tags).to contain_exactly(tag1, tag3)
      end

      it "removes all tags with empty array" do
        topic_ids =
          TopicsBulkAction.new(topic.user, [topic.id], type: "change_tags", tag_ids: []).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.tags).to be_empty
      end
    end

    context "when tagging fails due to tag restrictions" do
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:tag_group) do
        Fabricate(:tag_group, tags: [restricted_tag], permissions: { staff: :full })
      end

      it "does not include the topic in changed_ids and logs a warning" do
        Rails.logger.expects(:warn).with(includes("restricted-tag"))

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_tags",
            tag_ids: [restricted_tag.id],
          ).perform!

        expect(topic_ids).to eq([])
      end
    end

    context "when the user can't edit the topic" do
      fab!(:tag3, :tag)

      it "doesn't change the tags" do
        Guardian.any_instance.expects(:can_edit?).returns(false)

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "change_tags",
            tag_ids: [tag3.id],
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic.reload.tags).to contain_exactly(tag1, tag2)
      end
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

    context "when the user can edit the topic" do
      it "appends existing tags" do
        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "append_tags",
            tag_ids: [tag3.id],
          ).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.tags).to contain_exactly(tag1, tag2, tag3)
      end

      it "keeps existing tags when appending empty array" do
        topic_ids =
          TopicsBulkAction.new(topic.user, [topic.id], type: "append_tags", tag_ids: []).perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.tags).to contain_exactly(tag1, tag2)
      end
    end

    context "when tagging fails due to tag restrictions" do
      fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
      fab!(:tag_group) do
        Fabricate(:tag_group, tags: [restricted_tag], permissions: { staff: :full })
      end

      it "does not include the topic in changed_ids and logs a warning" do
        Rails.logger.expects(:warn).with(includes("restricted-tag"))

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "append_tags",
            tag_ids: [restricted_tag.id],
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic.reload.tags).to contain_exactly(tag1, tag2)
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't change the tags" do
        Guardian.any_instance.expects(:can_edit?).returns(false)

        topic_ids =
          TopicsBulkAction.new(
            topic.user,
            [topic.id],
            type: "append_tags",
            tag_ids: [tag3.id],
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic.reload.tags).to contain_exactly(tag1, tag2)
      end
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

    context "when the user can edit the topic" do
      it "removes all tags and updates tag counts" do
        expect(tag1.reload.staff_topic_count).to eq(1)

        topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "remove_tags").perform!

        expect(topic_ids).to eq([topic.id])
        expect(topic.reload.tags).to be_empty
        expect(tag1.reload.staff_topic_count).to eq(0)
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't remove the tags" do
        Guardian.any_instance.expects(:can_edit?).returns(false)

        topic_ids = TopicsBulkAction.new(topic.user, [topic.id], type: "remove_tags").perform!

        expect(topic_ids).to eq([])
        expect(topic.reload.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
      end
    end

    context "when category requires minimum tags" do
      fab!(:tag3, :tag)
      fab!(:category_with_min_tags) { Fabricate(:category, minimum_required_tags: 2) }
      fab!(:topic_in_category) do
        Fabricate(:topic, category: category_with_min_tags, tags: [tag1, tag2])
      end
      fab!(:first_post) { Fabricate(:post, topic: topic_in_category) }
      fab!(:admin)

      it "prevents non-admin from removing tags when minimum required" do
        topic_ids =
          TopicsBulkAction.new(
            topic_in_category.user,
            [topic_in_category.id],
            type: "remove_tags",
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_in_category.reload.tags).to contain_exactly(tag1, tag2)
      end

      it "allows admin to remove tags even when minimum required" do
        topic_ids =
          TopicsBulkAction.new(admin, [topic_in_category.id], type: "remove_tags").perform!

        expect(topic_ids).to eq([topic_in_category.id])
        expect(topic_in_category.reload.tags).to be_empty
      end
    end

    context "when category has required tag groups" do
      fab!(:tag_group) { Fabricate(:tag_group, tags: [tag1, tag2]) }
      fab!(:category_with_required_group, :category)
      fab!(:topic_in_category) do
        Fabricate(:topic, category: category_with_required_group, tags: [tag1])
      end
      fab!(:first_post) { Fabricate(:post, topic: topic_in_category) }
      fab!(:admin)

      before do
        CategoryRequiredTagGroup.create!(
          category: category_with_required_group,
          tag_group: tag_group,
          min_count: 1,
        )
      end

      it "prevents non-admin from removing tags when tag group required" do
        topic_ids =
          TopicsBulkAction.new(
            topic_in_category.user,
            [topic_in_category.id],
            type: "remove_tags",
          ).perform!

        expect(topic_ids).to eq([])
        expect(topic_in_category.reload.tags).to contain_exactly(tag1)
      end

      it "allows admin to remove tags even when tag group required" do
        topic_ids =
          TopicsBulkAction.new(admin, [topic_in_category.id], type: "remove_tags").perform!

        expect(topic_ids).to eq([topic_in_category.id])
        expect(topic_in_category.reload.tags).to be_empty
      end
    end
  end
end
