# frozen_string_literal: true

require 'rails_helper'

describe TopicsBulkAction do
  fab!(:topic) { Fabricate(:topic) }

  describe "#dismiss_topics" do
    fab!(:user) { Fabricate(:user, created_at: 1.days.ago) }
    fab!(:category) { Fabricate(:category) }
    fab!(:topic2) { Fabricate(:topic, category: category, created_at: 60.minutes.ago) }
    fab!(:topic3) { Fabricate(:topic, category: category, created_at: 120.minutes.ago) }

    before do
      topic.destroy!
    end

    it 'dismisses private messages' do
      pm = Fabricate(:private_message_topic)

      TopicsBulkAction.new(user, [pm.id], type: "dismiss_topics").perform!

      expect(DismissedTopicUser.exists?(topic: pm)).to eq(true)
    end

    it 'dismisses two topics' do
      expect { TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform! }.to change { DismissedTopicUser.count }.by(2)
    end

    it 'returns dismissed topic ids' do
      expect(TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!.sort).to match_array(
        [topic2.id, topic3.id]
      )
    end

    it 'respects max_new_topics limit' do
      SiteSetting.max_new_topics = 1
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic2.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end

    it 'respects seen topics' do
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: 1)
      Fabricate(:topic_user, user: user, topic: topic3, last_read_post_number: 1)
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(0)
    end

    it 'dismisses when topic user without last_read_post_number' do
      Fabricate(:topic_user, user: user, topic: topic2, last_read_post_number: nil)
      Fabricate(:topic_user, user: user, topic: topic3, last_read_post_number: nil)
      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(2)
    end

    it 'respects new_topic_duration_minutes' do
      user.user_option.update!(new_topic_duration_minutes: 70)

      expect do
        TopicsBulkAction.new(user, [Topic.all.pluck(:id)], type: "dismiss_topics").perform!
      end.to change { DismissedTopicUser.count }.by(1)

      dismissed_topic_user = DismissedTopicUser.last

      expect(dismissed_topic_user.user_id).to eq(user.id)
      expect(dismissed_topic_user.topic_id).to eq(topic2.id)
      expect(dismissed_topic_user.created_at).not_to be_nil
    end
  end

  describe "dismiss_posts" do
    it "dismisses posts" do
      post1 = create_post
      p = create_post(topic_id: post1.topic_id)
      create_post(topic_id: post1.topic_id)

      PostDestroyer.new(Fabricate(:admin), p).destroy

      TopicsBulkAction.new(post1.user, [post1.topic_id], type: 'dismiss_posts').perform!

      tu = TopicUser.find_by(user_id: post1.user_id, topic_id: post1.topic_id)

      expect(tu.last_read_post_number).to eq(3)
    end

    context "when the user is staff" do
      fab!(:user) { Fabricate(:admin) }

      context "when the highest_staff_post_number is > highest_post_number for a topic (e.g. whisper is last post)" do
        it "dismisses posts" do
          post1 = create_post(user: user)
          p = create_post(topic_id: post1.topic_id)
          create_post(topic_id: post1.topic_id)

          whisper = PostCreator.new(
            user,
            topic_id: post1.topic.id,
            post_type: Post.types[:whisper],
            raw: 'this is a whispered reply'
          ).create

          TopicsBulkAction.new(user, [post1.topic_id], type: 'dismiss_posts').perform!

          tu = TopicUser.find_by(user_id: user.id, topic_id: post1.topic_id)

          expect(tu.last_read_post_number).to eq(4)
        end
      end
    end
  end

  describe "invalid operation" do
    let(:user) { Fabricate.build(:user) }

    it "raises an error with an invalid operation" do
      tba = TopicsBulkAction.new(user, [1], type: 'rm_root')
      expect { tba.perform! }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "change_category" do
    fab!(:category) { Fabricate(:category) }
    fab!(:fist_post) { Fabricate(:post, topic: topic) }

    context "when the user can edit the topic" do
      context "with 'create_revision_on_bulk_topic_moves' setting enabled" do
        before do
          SiteSetting.create_revision_on_bulk_topic_moves = true
        end

        it "changes the category, creates a post revision and returns the topic_id" do
          old_category_id = topic.category_id
          tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: category.id)
          topic_ids = tba.perform!
          expect(topic_ids).to eq([topic.id])
          topic.reload
          expect(topic.category).to eq(category)

          revision = topic.first_post.revisions.last
          expect(revision).to be_present
          expect(revision.modifications).to eq ({ "category_id" => [old_category_id, category.id] })
        end

        it "doesn't do anything when category stays the same" do
          tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: topic.category_id)
          topic_ids = tba.perform!
          expect(topic_ids).to be_empty

          topic.reload
          revision = topic.first_post.revisions.last
          expect(revision).to be_nil
        end
      end

      context "with 'create_revision_on_bulk_topic_moves' setting disabled" do
        before do
          SiteSetting.create_revision_on_bulk_topic_moves = false
        end

        it "changes the category, doesn't create a post revision and returns the topic_id" do
          tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: category.id)
          topic_ids = tba.perform!
          expect(topic_ids).to eq([topic.id])
          topic.reload
          expect(topic.category).to eq(category)

          revision = topic.first_post.revisions.last
          expect(revision).to be_nil
        end

        it "doesn't do anything when category stays the same" do
          tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: topic.category_id)
          topic_ids = tba.perform!
          expect(topic_ids).to be_empty
        end
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't change the category" do
        Guardian.any_instance.expects(:can_edit?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_category', category_id: category.id)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        topic.reload
        expect(topic.category).not_to eq(category)
      end
    end
  end

  describe "reset_read" do
    it "delegates to PostTiming.destroy_for" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'reset_read')
      PostTiming.expects(:destroy_for).with(topic.user_id, [topic.id])
      topic_ids = tba.perform!
    end
  end

  describe "delete" do
    fab!(:topic) { Fabricate(:post).topic }
    fab!(:moderator) { Fabricate(:moderator) }

    it "deletes the topic" do
      tba = TopicsBulkAction.new(moderator, [topic.id], type: 'delete')
      tba.perform!
      topic.reload
      expect(topic).to be_trashed
    end
  end

  describe "change_notification_level" do
    context "when the user can see the topic" do
      it "updates the notification level" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        expect(TopicUser.get(topic, topic.user).notification_level).to eq(2)
      end
    end

    context "when the user can't see the topic" do
      it "doesn't change the level" do
        Guardian.any_instance.expects(:can_see?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_notification_level', notification_level_id: 2)
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        expect(TopicUser.get(topic, topic.user)).to be_blank
      end
    end
  end

  describe "close" do
    context "when the user can moderate the topic" do
      it "closes the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic).to be_closed
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't close the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'close')
        topic_ids = tba.perform!
        expect(topic_ids).to be_blank
        topic.reload
        expect(topic).not_to be_closed
      end
    end
  end

  describe "archive" do
    context "when the user can moderate the topic" do
      it "archives the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'archive')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic).to be_archived
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't archive the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'archive')
        topic_ids = tba.perform!
        expect(topic_ids).to be_blank
        topic.reload
        expect(topic).not_to be_archived
      end
    end
  end

  describe "unlist" do
    context "when the user can moderate the topic" do
      it "unlists the topic and returns the topic_id" do
        Guardian.any_instance.expects(:can_moderate?).returns(true)
        Guardian.any_instance.expects(:can_create?).returns(true)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'unlist')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic).not_to be_visible
      end
    end

    context "when the user can't edit the topic" do
      it "doesn't unlist the topic" do
        Guardian.any_instance.expects(:can_moderate?).returns(false)
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'unlist')
        topic_ids = tba.perform!
        expect(topic_ids).to be_blank
        topic.reload
        expect(topic).to be_visible
      end
    end
  end

  describe "change_tags" do
    fab!(:tag1)  { Fabricate(:tag) }
    fab!(:tag2)  { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_level_to_tag_topics = 0
      topic.tags = [tag1, tag2]
    end

    it "can change the tags, and can create new tags" do
      SiteSetting.min_trust_to_create_tag = 0
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_tags', tags: ['newtag', tag1.name])
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.map(&:name)).to contain_exactly('newtag', tag1.name)
    end

    it "can change the tags but not create new ones" do
      SiteSetting.min_trust_to_create_tag = 4
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_tags', tags: ['newtag', tag1.name])
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.map(&:name)).to contain_exactly(tag1.name)
    end

    it "can remove all tags" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_tags', tags: [])
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.size).to eq(0)
    end

    context "when user can't edit topic" do
      before do
        Guardian.any_instance.expects(:can_edit?).returns(false)
      end

      it "doesn't change the tags" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'change_tags', tags: ['newtag', tag1.name])
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        topic.reload
        expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
      end
    end
  end

  describe "append tags" do
    fab!(:tag1)  { Fabricate(:tag) }
    fab!(:tag2)  { Fabricate(:tag) }
    fab!(:tag3)  { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_level_to_tag_topics = 0
      topic.tags = [tag1, tag2]
    end

    it "can append new or existing tags" do
      SiteSetting.min_trust_to_create_tag = 0
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'append_tags', tags: [tag1.name, tag3.name, 'newtag'])
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name, tag3.name, 'newtag')
    end

    it "can append empty tags" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'append_tags', tags: [])
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
    end

    context "when the user can't create new topics" do
      before do
        SiteSetting.min_trust_to_create_tag = 4
      end

      it "can append existing tags but doesn't append new tags" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'append_tags', tags: [tag3.name, 'newtag'])
        topic_ids = tba.perform!
        expect(topic_ids).to eq([topic.id])
        topic.reload
        expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name, tag3.name)
      end
    end

    context "when user can't edit topic" do
      before do
        Guardian.any_instance.expects(:can_edit?).returns(false)
      end

      it "doesn't change the tags" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'append_tags', tags: ['newtag', tag3.name])
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        topic.reload
        expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
      end
    end
  end

  describe "remove_tags" do
    fab!(:tag1)  { Fabricate(:tag) }
    fab!(:tag2)  { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.min_trust_level_to_tag_topics = 0
      topic.tags = [tag1, tag2]
    end

    it "can remove all tags" do
      tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'remove_tags')
      topic_ids = tba.perform!
      expect(topic_ids).to eq([topic.id])
      topic.reload
      expect(topic.tags.size).to eq(0)
    end

    context "when user can't edit topic" do
      before do
        Guardian.any_instance.expects(:can_edit?).returns(false)
      end

      it "doesn't remove the tags" do
        tba = TopicsBulkAction.new(topic.user, [topic.id], type: 'remove_tags')
        topic_ids = tba.perform!
        expect(topic_ids).to eq([])
        topic.reload
        expect(topic.tags.map(&:name)).to contain_exactly(tag1.name, tag2.name)
      end
    end
  end

end
