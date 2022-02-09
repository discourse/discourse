# coding: utf-8
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TopicsController do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:dest_topic) { Fabricate(:topic) }
  fab!(:invisible_topic) { Fabricate(:topic, visible: false) }

  fab!(:pm) { Fabricate(:private_message_topic) }

  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:post_author1) { Fabricate(:user) }
  fab!(:post_author2) { Fabricate(:user) }
  fab!(:post_author3) { Fabricate(:user) }
  fab!(:post_author4) { Fabricate(:user) }
  fab!(:post_author5) { Fabricate(:user) }
  fab!(:post_author6) { Fabricate(:user) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:trust_level_0) { Fabricate(:trust_level_0) }
  fab!(:trust_level_1) { Fabricate(:trust_level_1) }
  fab!(:trust_level_4) { Fabricate(:trust_level_4) }

  fab!(:category) { Fabricate(:category) }
  fab!(:tracked_category) { Fabricate(:category) }
  fab!(:shared_drafts_category) { Fabricate(:category) }
  fab!(:staff_category) {
    Fabricate(:category).tap { |staff_category|
      staff_category.set_permissions(staff: :full)
      staff_category.save!
    }
  }

  fab!(:group_user) { Fabricate(:group_user) }

  fab!(:tag) { Fabricate(:tag) }

  describe '#wordpress' do
    before do
      sign_in(moderator)
    end

    fab!(:p1) { Fabricate(:post, user: moderator) }
    fab!(:p2) { Fabricate(:post, topic: p1.topic, user: moderator) }

    it "returns the JSON in the format our wordpress plugin needs" do
      SiteSetting.external_system_avatars_enabled = false

      get "/t/#{p1.topic.id}/wordpress.json", params: { best: 3 }

      expect(response.status).to eq(200)
      json = response.parsed_body

      # The JSON has the data the wordpress plugin needs
      expect(json['id']).to eq(p1.topic.id)
      expect(json['posts_count']).to eq(2)
      expect(json['filtered_posts_count']).to eq(2)

      # Posts
      expect(json['posts'].size).to eq(1)
      post = json['posts'][0]
      expect(post['id']).to eq(p2.id)
      expect(post['username']).to eq(moderator.username)
      expect(post['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{moderator.avatar_template}")
      expect(post['name']).to eq(moderator.name)
      expect(post['created_at']).to be_present
      expect(post['cooked']).to eq(p2.cooked)

      # Participants
      expect(json['participants'].size).to eq(1)
      participant = json['participants'][0]
      expect(participant['id']).to eq(moderator.id)
      expect(participant['username']).to eq(moderator.username)
      expect(participant['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{moderator.avatar_template}")
    end
  end

  describe '#move_posts' do
    before do
      SiteSetting.min_topic_title_length = 2
      SiteSetting.tagging_enabled = true
    end

    it 'needs you to be logged in' do
      post "/t/111/move-posts.json", params: {
        title: 'blah',
        post_ids: [1, 2, 3]
      }
      expect(response.status).to eq(403)
    end

    describe 'moving to a new topic' do
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1) }
      let(:p2) { Fabricate(:post, user: user, post_number: 2, topic: p1.topic) }
      let(:topic) { p1.topic }

      it "raises an error without post_ids" do
        sign_in(moderator)
        post "/t/#{topic.id}/move-posts.json", params: { title: 'blah' }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        sign_in(user)

        post "/t/#{topic.id}/move-posts.json", params: {
          title: 'blah', post_ids: [p1.post_number, p2.post_number]
        }

        expect(response).to be_forbidden
      end

      it "raises an error when the OP is not a regular post" do
        sign_in(moderator)
        p2 = Fabricate(:post, user: post_author1, topic: topic, post_number: 2, post_type: Post.types[:whisper])
        p3 = Fabricate(:post, user: post_author2, topic: topic, post_number: 3)

        post "/t/#{topic.id}/move-posts.json", params: {
          title: 'blah', post_ids: [p2.id, p3.id]
        }
        expect(response.status).to eq(422)

        result = response.parsed_body

        expect(result['errors']).to be_present
      end

      context 'success' do

        before { sign_in(admin) }

        it "returns success" do
          expect do
            post "/t/#{topic.id}/move-posts.json", params: {
              title: 'Logan is a good movie',
              post_ids: [p2.id],
              category_id: category.id,
              tags: ["foo", "bar"]
            }
          end.to change { Topic.count }.by(1).and change { Tag.count }.by(2)

          expect(response.status).to eq(200)

          result = response.parsed_body

          expect(result['success']).to eq(true)

          new_topic = Topic.last
          expect(result['url']).to eq(new_topic.relative_url)
          expect(new_topic.excerpt).to eq(p2.excerpt_for_topic)
          expect(Tag.all.pluck(:name)).to include("foo", "bar")
        end

        describe 'when topic has been deleted' do
          it 'should still be able to move posts' do
            PostDestroyer.new(admin, topic.first_post).destroy

            expect(topic.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{topic.id}/move-posts.json", params: {
                title: 'Logan is a good movie',
                post_ids: [p2.id],
                category_id: category.id
              }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = response.parsed_body

            expect(result['success']).to eq(true)
            expect(result['url']).to eq(Topic.last.relative_url)
          end
        end
      end

      context 'failure' do
        it "returns JSON with a false success" do
          sign_in(moderator)
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p2.id]
          }
          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end

      describe "moving replied posts" do
        context 'success' do
          it "moves the child posts too" do
            sign_in(moderator)
            p1 = Fabricate(:post, topic: topic, user: moderator)
            p2 = Fabricate(:post, topic: topic, user: moderator, reply_to_post_number: p1.post_number)
            PostReply.create(post_id: p1.id, reply_post_id: p2.id)

            post "/t/#{topic.id}/move-posts.json", params: {
              title: 'new topic title',
              post_ids: [p1.id],
              reply_post_ids: [p1.id]
            }
            expect(response.status).to eq(200)

            p1.reload
            p2.reload

            new_topic_id = response.parsed_body["url"].split("/").last.to_i
            new_topic = Topic.find(new_topic_id)
            expect(p1.topic.id).to eq(new_topic.id)
            expect(p2.topic.id).to eq(new_topic.id)
            expect(p2.reply_to_post_number).to eq(p1.post_number)
          end
        end
      end
    end

    describe "moving to a new topic as a group moderator" do
      fab!(:category) { Fabricate(:category, reviewable_by_group: group_user.group) }
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: group_user.user, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: group_user.user, post_number: 2, topic: topic) }
      let!(:user) { group_user.user }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        expect do
          post "/t/#{topic.id}/move-posts.json", params: {
            title: 'Logan is a good movie',
            post_ids: [p2.id],
            category_id: category.id
          }
        end.to change { Topic.count }.by(1)

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result['success']).to eq(true)
        expect(result['url']).to eq(Topic.last.relative_url)
      end

      it "does not allow posts to be moved to a private category" do
        post "/t/#{topic.id}/move-posts.json", params: {
          title: 'Logan is a good movie',
          post_ids: [p2.id],
          category_id: staff_category.id
        }

        expect(response).to be_forbidden
      end

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/move-posts.json", params: {
          title: 'blah', post_ids: [p1.post_number, p2.post_number]
        }

        expect(response).to be_forbidden
      end
    end

    describe 'moving to an existing topic' do
      before do
        sign_in(moderator)
      end

      fab!(:p1) { Fabricate(:post, user: moderator) }
      fab!(:topic) { p1.topic }
      fab!(:p2) { Fabricate(:post, user: moderator, topic: topic) }

      context 'success' do
        it "returns success" do
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p2.id],
            destination_topic_id: dest_topic.id
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end

        it "triggers an event on merge" do
          begin
            called = false

            assert = -> (original_topic, destination_topic) do
              called = true
              expect(original_topic).to eq(topic)
              expect(destination_topic).to eq(dest_topic)
            end

            DiscourseEvent.on(:topic_merged, &assert)

            post "/t/#{topic.id}/move-posts.json", params: {
              post_ids: [p2.id],
              destination_topic_id: dest_topic.id
            }

            expect(called).to eq(true)
            expect(response.status).to eq(200)
          ensure
            DiscourseEvent.off(:topic_merged, &assert)
          end
        end
      end

      context 'failure' do
        fab!(:p2) { Fabricate(:post, user: moderator) }
        it "returns JSON with a false success" do
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p2.id]
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end

        it 'returns plugin validation error' do
          # stub here is to simulate validation added by plugin which would be triggered when post is moved
          PostCreator.any_instance.stubs(:skip_validations?).returns(false)

          p1.update_columns(raw: "i", cooked: "")
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p1.id],
            destination_topic_id: dest_topic.id
          }

          expect(response.status).to eq(422)
          result = response.parsed_body
          expect(result['errors']).to eq(["Body is too short (minimum is 5 characters) and Body seems unclear, is it a complete sentence?"])
        end
      end
    end

    describe "moving to an existing topic as a group moderator" do
      fab!(:category) { Fabricate(:category, reviewable_by_group: group_user.group) }
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: group_user.user, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: group_user.user, post_number: 2, topic: topic) }

      let!(:user) { group_user.user }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        post "/t/#{topic.id}/move-posts.json", params: {
          post_ids: [p2.id],
          destination_topic_id: dest_topic.id
        }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result['success']).to eq(true)
        expect(result['url']).to be_present
      end

      it "does not allow posts to be moved to a private category" do
        dest_topic.update!(category: staff_category)

        post "/t/#{topic.id}/move-posts.json", params: {
          post_ids: [p2.id],
          destination_topic_id: dest_topic.id
        }

        expect(response).to be_forbidden
      end

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/move-posts.json", params: {
          post_ids: [p1.post_number, p2.post_number],
          destination_topic_id: dest_topic.id
        }

        expect(response).to be_forbidden
      end
    end

    describe 'moving to a new message' do
      fab!(:message) { pm }
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: message) }
      fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: message) }

      it "raises an error without post_ids" do
        sign_in(moderator)
        post "/t/#{message.id}/move-posts.json", params: { title: 'blah', archetype: 'private_message' }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        sign_in(trust_level_4)

        post "/t/#{message.id}/move-posts.json", params: {
          title: 'blah', post_ids: [p1.post_number, p2.post_number], archetype: 'private_message'
        }

        expect(response.status).to eq(403)
        result = response.parsed_body
        expect(result['errors']).to be_present
      end

      context 'success' do
        before { sign_in(admin) }

        it "returns success" do
          SiteSetting.allow_staff_to_tag_pms = true

          expect do
            post "/t/#{message.id}/move-posts.json", params: {
              title: 'Logan is a good movie',
              post_ids: [p2.id],
              archetype: 'private_message',
              tags: ["foo", "bar"]
            }
          end.to change { Topic.count }.by(1).and change { Tag.count }.by(2)

          expect(response.status).to eq(200)

          result = response.parsed_body

          expect(result['success']).to eq(true)
          expect(result['url']).to eq(Topic.last.relative_url)
          expect(Tag.all.pluck(:name)).to include("foo", "bar")
        end

        describe 'when message has been deleted' do
          it 'should still be able to move posts' do
            PostDestroyer.new(admin, message.first_post).destroy

            expect(message.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{message.id}/move-posts.json", params: {
                title: 'Logan is a good movie',
                post_ids: [p2.id],
                archetype: 'private_message'
              }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = response.parsed_body

            expect(result['success']).to eq(true)
            expect(result['url']).to eq(Topic.last.relative_url)
          end
        end
      end

      context 'failure' do
        it "returns JSON with a false success" do
          sign_in(moderator)
          post "/t/#{message.id}/move-posts.json", params: {
            post_ids: [p2.id],
            archetype: 'private_message'
          }
          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end

    describe 'moving to an existing message' do
      before do
        sign_in(admin)
      end

      fab!(:evil_trout) { Fabricate(:evil_trout) }
      fab!(:message) { pm }
      fab!(:p2) { Fabricate(:post, user: evil_trout, post_number: 2, topic: message) }

      fab!(:dest_message) do
        Fabricate(:private_message_topic, user: trust_level_4, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: evil_trout)
        ])
      end

      context 'success' do
        it "returns success" do
          post "/t/#{message.id}/move-posts.json", params: {
            post_ids: [p2.id],
            destination_topic_id: dest_message.id,
            archetype: 'private_message'
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end

      context 'failure' do
        it "returns JSON with a false success" do
          post "/t/#{message.id}/move-posts.json", params: {
            post_ids: [p2.id],
            archetype: 'private_message'
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end
  end

  describe '#merge_topic' do
    it 'needs you to be logged in' do
      post "/t/111/merge-topic.json", params: {
        destination_topic_id: 345
      }
      expect(response.status).to eq(403)
    end

    describe 'merging into another topic' do
      fab!(:p1) { Fabricate(:post, user: user) }
      fab!(:topic) { p1.topic }

      it "raises an error without destination_topic_id" do
        sign_in(moderator)
        post "/t/#{topic.id}/merge-topic.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to merge" do
        sign_in(user)
        post "/t/111/merge-topic.json", params: { destination_topic_id: 345 }
        expect(response).to be_forbidden
      end

      context 'moves all the posts to the destination topic' do
        it "returns success" do
          sign_in(moderator)
          post "/t/#{topic.id}/merge-topic.json", params: {
            destination_topic_id: dest_topic.id
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end

    describe "merging into another topic as a group moderator" do
      fab!(:category) { Fabricate(:category, reviewable_by_group: group_user.group) }
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: post_author1, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: post_author2, post_number: 2, topic: topic) }

      before do
        sign_in(group_user.user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        post "/t/#{topic.id}/merge-topic.json", params: {
          destination_topic_id: dest_topic.id
        }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result['success']).to eq(true)
        expect(result['url']).to be_present
      end

      it "does not allow posts to be moved to a private category" do
        dest_topic.update!(category: staff_category)

        post "/t/#{topic.id}/merge-topic.json", params: {
          destination_topic_id: dest_topic.id
        }

        expect(response).to be_forbidden
      end

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/merge-topic.json", params: {
          destination_topic_id: dest_topic.id
        }

        expect(response).to be_forbidden
      end
    end

    describe 'merging into another message' do
      fab!(:message) { Fabricate(:private_message_topic, user: user) }
      fab!(:p1) { Fabricate(:post, topic: message, user: trust_level_4) }
      fab!(:p2) { Fabricate(:post, topic: message, reply_to_post_number: p1.post_number, user: user) }

      fab!(:dest_message) do
        Fabricate(:private_message_topic, user: trust_level_4, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: moderator)
        ])
      end

      it "raises an error without destination_topic_id" do
        sign_in(moderator)
        post "/t/#{message.id}/merge-topic.json", params: {
          archetype: 'private_message'
        }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to merge" do
        sign_in(trust_level_4)
        post "/t/#{message.id}/merge-topic.json", params: {
          destination_topic_id: 345,
          archetype: 'private_message'
        }
        expect(response).to be_forbidden
      end

      context 'moves all the posts to the destination message' do
        it "returns success" do
          sign_in(moderator)
          post "/t/#{message.id}/merge-topic.json", params: {
            destination_topic_id: dest_message.id,
            archetype: 'private_message'
          }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end
  end

  describe '#change_post_owners' do
    it 'needs you to be logged in' do
      post "/t/111/change-owner.json", params: {
        username: 'user_a',
        post_ids: [1, 2, 3]
      }
      expect(response).to be_forbidden
    end

    describe 'forbidden to trust_level_4s' do
      before do
        sign_in(trust_level_4)
      end

      it 'correctly denies' do
        post "/t/111/change-owner.json", params: {
          topic_id: 111, username: 'user_a', post_ids: [1, 2, 3]
        }
        expect(response).to be_forbidden
      end
    end

    describe 'changing ownership' do
      fab!(:user_a) { Fabricate(:user) }
      fab!(:p1) { Fabricate(:post, user: post_author1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: post_author2, topic: topic) }

      describe 'moderator signed in' do
        let!(:editor) { sign_in(moderator) }

        it "returns 200 when moderators_change_post_ownership is true" do
          SiteSetting.moderators_change_post_ownership = true

          post "/t/#{topic.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p1.id]
          }
          expect(response.status).to eq(200)
        end

        it "returns 403 when moderators_change_post_ownership is false" do
          SiteSetting.moderators_change_post_ownership = false

          post "/t/#{topic.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p1.id]
          }
          expect(response.status).to eq(403)
        end
      end
      describe 'admin signed in' do
        let!(:editor) { sign_in(admin) }

        it "raises an error with a parameter missing" do
          [
            { post_ids: [1, 2, 3] },
            { username: 'user_a' }
          ].each do |params|
            post "/t/111/change-owner.json", params: params
            expect(response.status).to eq(400)
          end
        end

        it "changes the topic and posts ownership" do
          post "/t/#{topic.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p1.id]
          }
          topic.reload
          p1.reload
          expect(response.status).to eq(200)
          expect(topic.user.username).to eq(user_a.username)
          expect(p1.user.username).to eq(user_a.username)
        end

        it "changes multiple posts" do
          post "/t/#{topic.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p1.id, p2.id]
          }

          expect(response.status).to eq(200)

          p1.reload
          p2.reload

          expect(p1.user).to_not eq(nil)
          expect(p1.reload.user).to eq(p2.reload.user)
        end

        it "works with deleted users" do
          deleted_user = user
          t2 = Fabricate(:topic, user: deleted_user)
          p3 = Fabricate(:post, topic: t2, user: deleted_user)

          UserDestroyer.new(editor).destroy(deleted_user, delete_posts: true, context: 'test', delete_as_spammer: true)

          post "/t/#{t2.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p3.id]
          }

          expect(response.status).to eq(200)
          t2.reload
          p3.reload
          expect(t2.deleted_at).to be_nil
          expect(p3.user).to eq(user_a)
        end

        it "removes likes by new owner" do
          now = Time.zone.now
          freeze_time(now - 1.day)
          PostActionCreator.like(user_a, p1)
          p1.reload
          freeze_time(now)
          post "/t/#{topic.id}/change-owner.json", params: {
            username: user_a.username_lower, post_ids: [p1.id]
          }
          topic.reload
          p1.reload
          expect(response.status).to eq(200)
          expect(topic.user.username).to eq(user_a.username)
          expect(p1.user.username).to eq(user_a.username)
          expect(p1.like_count).to eq(0)
        end
      end
    end
  end

  describe '#change_timestamps' do
    let!(:params) { { timestamp: Time.zone.now } }

    it 'needs you to be logged in' do
      put "/t/1/change-timestamp.json", params: params
      expect(response.status).to eq(403)
    end

    describe "forbidden to trust_level_4" do
      before do
        sign_in(trust_level_4)
      end

      it 'correctly denies' do
        put "/t/1/change-timestamp.json", params: params
        expect(response).to be_forbidden
      end
    end

    describe 'changing timestamps' do
      before do
        freeze_time
        sign_in(moderator)
      end

      let!(:old_timestamp) { Time.zone.now }
      let!(:new_timestamp) { old_timestamp - 1.day }
      let!(:topic) { Fabricate(:topic, created_at: old_timestamp) }
      let!(:p1) { Fabricate(:post, user: post_author1, topic: topic, created_at: old_timestamp) }
      let!(:p2) { Fabricate(:post, user: post_author2, topic: topic, created_at: old_timestamp + 1.day) }

      it 'should update the timestamps of selected posts' do
        # try to see if we fail with invalid first
        put "/t/1/change-timestamp.json"
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/change-timestamp.json", params: {
          timestamp: new_timestamp.to_f
        }

        expect(response.status).to eq(200)
        expect(topic.reload.created_at).to eq_time(new_timestamp)
        expect(p1.reload.created_at).to eq_time(new_timestamp)
        expect(p2.reload.created_at).to eq_time(old_timestamp)
      end

      it 'should create a staff log entry' do
        put "/t/#{topic.id}/change-timestamp.json", params: {
          timestamp: new_timestamp.to_f
        }

        log = UserHistory.last
        expect(log.acting_user_id).to eq(moderator.id)
        expect(log.topic_id).to eq(topic.id)
        expect(log.new_value).to eq(new_timestamp.utc.to_s)
        expect(log.previous_value).to eq(old_timestamp.utc.to_s)
      end
    end
  end

  describe '#clear_pin' do
    it 'needs you to be logged in' do
      put "/t/1/clear-pin.json"
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      before do
        sign_in(user)
      end

      it "fails when the user can't see the topic" do
        put "/t/#{pm.id}/clear-pin.json"
        expect(response).to be_forbidden
      end

      describe 'when the user can see the topic' do
        it "succeeds" do
          expect do
            put "/t/#{topic.id}/clear-pin.json"
          end.to change { TopicUser.where(topic_id: topic.id, user_id: user.id).count }.by(1)
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe '#status' do
    it 'needs you to be logged in' do
      put "/t/1/status.json", params: {
        status: 'visible', enabled: true
      }
      expect(response.status).to eq(403)
    end

    describe 'when logged in as a moderator' do
      before do
        sign_in(moderator)
      end

      it "raises an exception if you can't change it" do
        sign_in(user)
        put "/t/#{topic.id}/status.json", params: {
          status: 'visible', enabled: 'true'
        }
        expect(response).to be_forbidden
      end

      it 'requires the status parameter' do
        put "/t/#{topic.id}/status.json", params: { enabled: true }
        expect(response.status).to eq(400)
      end

      it 'requires the enabled parameter' do
        put "/t/#{topic.id}/status.json", params: { status: 'visible' }
        expect(response.status).to eq(400)
      end

      it 'raises an error with a status not in the allowlist' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'title', enabled: 'true'
        }
        expect(response.status).to eq(400)
      end

      it 'should update the status of the topic correctly' do
        closed_user_topic = Fabricate(:topic, user: user, closed: true)
        Fabricate(:topic_timer, topic: closed_user_topic, status_type: TopicTimer.types[:open])

        put "/t/#{closed_user_topic.id}/status.json", params: {
          status: 'closed', enabled: 'false'
        }

        expect(response.status).to eq(200)
        expect(closed_user_topic.reload.closed).to eq(false)
        expect(closed_user_topic.topic_timers).to eq([])

        body = response.parsed_body

        expect(body['topic_status_update']).to eq(nil)
      end
    end

    describe 'when logged in as a group member with reviewable status' do
      fab!(:category) { Fabricate(:category, reviewable_by_group: group_user.group) }
      fab!(:topic) { Fabricate(:topic, category: category) }

      before do
        sign_in(group_user.user)
        SiteSetting.enable_category_group_moderation = true
      end

      it 'should allow a group moderator to close a topic' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'closed', enabled: 'true'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(true)
        expect(topic.posts.last.action_code).to eq('closed.enabled')
      end

      it 'should allow a group moderator to open a closed topic' do
        topic.update!(closed: true)

        expect do
          put "/t/#{topic.id}/status.json", params: {
            status: 'closed', enabled: 'false'
          }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(false)
        expect(topic.posts.last.action_code).to eq('closed.disabled')
      end

      it 'should allow a group moderator to archive a topic' do
        expect do
          put "/t/#{topic.id}/status.json", params: {
            status: 'archived', enabled: 'true'
          }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(true)
        expect(topic.posts.last.action_code).to eq('archived.enabled')
      end

      it 'should allow a group moderator to unarchive an archived topic' do
        topic.update!(archived: true)

        put "/t/#{topic.id}/status.json", params: {
          status: 'archived', enabled: 'false'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(false)
        expect(topic.posts.last.action_code).to eq('archived.disabled')
      end

      it 'should allow a group moderator to pin a topic' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'pinned', enabled: 'true', until: 2.weeks.from_now
        }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to_not eq(nil)
      end

      it 'should allow a group moderator to unpin a topic' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'pinned', enabled: 'false'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to eq(nil)
      end

      it 'should allow a group moderator to unlist a topic' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'visible', enabled: 'false'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.visible).to eq(false)
        expect(topic.posts.last.action_code).to eq('visible.disabled')
      end

      it 'should allow a group moderator to list an unlisted topic' do
        topic.update!(visible: false)

        put "/t/#{topic.id}/status.json", params: {
          status: 'visible', enabled: 'true'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.visible).to eq(true)
        expect(topic.posts.last.action_code).to eq('visible.enabled')
      end
    end
  end

  describe '#destroy_timings' do
    it 'needs you to be logged in' do
      delete "/t/1/timings.json"
      expect(response.status).to eq(403)
    end

    def topic_user_post_timings_count(user, topic)
      [TopicUser, PostTiming].map do |klass|
        klass.where(user: user, topic: topic).count
      end
    end

    context 'for last post only' do
      it 'should allow you to retain topic timing but remove last post only' do
        freeze_time

        post1 = create_post
        user = post1.user

        topic = post1.topic

        post2 = create_post(topic_id: topic.id)

        PostTiming.create!(topic: topic, user: user, post_number: 2, msecs: 100)

        user.user_stat.update!(first_unread_at: Time.now + 1.week)

        topic_user = TopicUser.find_by(
          topic_id: topic.id,
          user_id: user.id,
        )

        topic_user.update!(
          last_read_post_number: 2,
        )

        # ensure we have 2 notifications
        # fake notification on topic but it is read
        first_notification = Notification.create!(
          user_id: user.id,
          topic_id: topic.id,
          data: "{}",
          read: true,
          notification_type: 1
        )

        freeze_time 1.minute.from_now
        PostAlerter.post_created(post2)

        second_notification = user.notifications.where(topic_id: topic.id).order(created_at: :desc).first
        second_notification.update!(read: true)

        sign_in(user)

        delete "/t/#{topic.id}/timings.json?last=1"

        expect(PostTiming.where(topic: topic, user: user, post_number: 2).exists?).to eq(false)
        expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(true)

        expect(TopicUser.where(topic: topic, user: user, last_read_post_number: 1).exists?).to eq(true)

        user.user_stat.reload
        expect(user.user_stat.first_unread_at).to eq_time(topic.updated_at)

        first_notification.reload
        second_notification.reload
        expect(first_notification.read).to eq(true)
        expect(second_notification.read).to eq(false)

        PostDestroyer.new(admin, post2).destroy

        delete "/t/#{topic.id}/timings.json?last=1"

        expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(false)
        expect(TopicUser.where(topic: topic, user: user, last_read_post_number: nil).exists?).to eq(true)
      end
    end

    context 'when logged in' do
      fab!(:user_topic) { Fabricate(:topic, user: user) }
      fab!(:user_post) { Fabricate(:post, user: user, topic: user_topic, post_number: 2) }

      before do
        sign_in(user)
        TopicUser.create!(topic: user_topic, user: user)
        PostTiming.create!(topic: user_topic, user: user, post_number: 2, msecs: 1000)
      end

      it 'deletes the forum topic user and post timings records' do
        expect do
          delete "/t/#{user_topic.id}/timings.json"
        end.to change { topic_user_post_timings_count(user, user_topic) }.from([1, 1]).to([0, 0])
      end
    end
  end

  describe '#mute/unmute' do
    it 'needs you to be logged in' do
      put "/t/99/mute.json"
      expect(response.status).to eq(403)
    end

    it 'needs you to be logged in' do
      put "/t/99/unmute.json"
      expect(response.status).to eq(403)
    end
  end

  describe '#recover' do
    it "won't allow us to recover a topic when we're not logged in" do
      put "/t/1/recover.json"
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      let!(:topic) { Fabricate(:topic, user: user, deleted_at: Time.now, deleted_by: moderator) }
      let!(:post) { Fabricate(:post, user: user, topic: topic, post_number: 1, deleted_at: Time.now, deleted_by: moderator) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          sign_in(user)
          put "/t/#{topic.id}/recover.json"
          expect(response).to be_forbidden
        end
      end

      context 'with permission' do
        before do
          sign_in(moderator)
        end

        it 'succeeds' do
          put "/t/#{topic.id}/recover.json"
          topic.reload
          post.reload
          expect(response.status).to eq(200)
          expect(topic.trashed?).to be_falsey
          expect(post.trashed?).to be_falsey
        end
      end
    end
  end

  describe '#delete' do
    it "won't allow us to delete a topic when we're not logged in" do
      delete "/t/1.json"
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      fab!(:topic) { Fabricate(:topic, user: user, created_at: 48.hours.ago) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          sign_in(user)
          delete "/t/#{topic.id}.json"
          expect(response.status).to eq(422)
        end
      end

      describe 'with permission' do
        before do
          sign_in(moderator)
        end

        it 'succeeds' do
          delete "/t/#{topic.id}.json"
          expect(response.status).to eq(200)
          topic.reload
          expect(topic.trashed?).to be_truthy
        end
      end
    end
  end

  describe '#id_for_slug' do
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it "returns JSON for the slug" do
      get "/t/id_for/#{topic.slug}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json['topic_id']).to eq(topic.id)
      expect(json['url']).to eq(topic.url)
      expect(json['slug']).to eq(topic.slug)
    end

    it "returns invalid access if the user can't see the topic" do
      get "/t/id_for/#{pm.slug}.json"
      expect(response).to be_forbidden
    end
  end

  describe '#update' do
    it "won't allow us to update a topic when we're not logged in" do
      put "/t/1.json", params: { slug: 'xyz' }
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      fab!(:topic) { Fabricate(:topic, user: user) }

      before_all do
        Fabricate(:post, user: post_author1, topic: topic)
      end

      before do
        SiteSetting.editing_grace_period = 0
        sign_in(user)
      end

      it 'can not change category to a disallowed category' do
        category.set_permissions(staff: :full)
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      it 'can not move to a category that requires topic approval' do
        category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      context 'updating shared drafts' do
        fab!(:topic) { Fabricate(:topic, category: shared_drafts_category) }
        fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: Fabricate(:category)) }

        it 'changes destination category' do
          put "/t/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(403)
          expect(topic.shared_draft.category_id).not_to eq(category.id)
        end
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          topic.update!(archived: true)
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(403)
        end
      end

      describe 'with permission' do
        fab!(:post_hook) { Fabricate(:post_web_hook) }
        fab!(:topic_hook) { Fabricate(:topic_web_hook) }

        it 'succeeds' do
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body['basic_topic']).to be_present
        end

        it "throws an error if it could not be saved" do
          PostRevisor.any_instance.stubs(:should_revise?).returns(false)
          put "/t/#{topic.slug}/#{topic.id}.json", params: { title: "brand new title" }

          expect(response.status).to eq(422)
          expect(response.parsed_body['errors'].first).to eq(
            I18n.t("activerecord.errors.models.topic.attributes.base.unable_to_update")
          )
        end

        it "can update a topic to an uncategorized topic" do
          topic.update!(category: category)

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            category_id: ""
          }

          expect(response.status).to eq(200)
          expect(topic.reload.category_id).to eq(SiteSetting.uncategorized_category_id)
        end

        it 'allows a change of title' do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'This is a new title for the topic'
          }

          topic.reload
          expect(topic.title).to eq('This is a new title for the topic')

          # emits a topic_edited event but not a post_edited web hook event
          expect(Jobs::EmitWebHookEvent.jobs.length).to eq(1)
          job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

          expect(job_args["event_name"]).to eq("topic_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["title"]).to eq('This is a new title for the topic')
        end

        it 'allows a change of then updating the OP' do
          topic.update(user: user)
          topic.first_post.update(user: user)

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'This is a new title for the topic'
          }

          topic.reload
          expect(topic.title).to eq('This is a new title for the topic')

          update_params = {
            post: { raw: 'edited body', edit_reason: 'typo' },
          }
          put "/posts/#{topic.first_post.id}.json", params: update_params

          # emits a topic_edited event and a post_edited web hook event
          expect(Jobs::EmitWebHookEvent.jobs.length).to eq(2)
          job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

          expect(job_args["event_name"]).to eq("topic_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["title"]).to eq('This is a new title for the topic')

          job_args = Jobs::EmitWebHookEvent.jobs[1]["args"].first

          expect(job_args["event_name"]).to eq("post_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["raw"]).to eq("edited body")
        end

        it "returns errors with invalid titles" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'asdf'
          }

          expect(response.status).to eq(422)
          expect(response.parsed_body['errors']).to match_array([/Title is too short/, /Title seems unclear/])
        end

        it "returns errors when the rate limit is exceeded" do
          EditRateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'This is a new title for the topic'
          }

          expect(response.status).to eq(429)
        end

        it "returns errors with invalid categories" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            category_id: -1
          }

          expect(response.status).to eq(422)
        end

        it "doesn't call the PostRevisor when there is no changes" do
          expect do
            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: topic.category_id
            }
          end.not_to change(PostRevision.all, :count)

          expect(response.status).to eq(200)
        end

        context "when using SiteSetting.disable_category_edit_notifications" do
          it "doesn't bump the topic if the setting is enabled" do
            SiteSetting.disable_category_edit_notifications = true
            last_bumped_at = topic.bumped_at
            expect(last_bumped_at).not_to be_nil

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }
            end.to change { topic.reload.category_id }.to(category.id)

            expect(response.status).to eq(200)
            expect(topic.reload.bumped_at).to eq_time(last_bumped_at)
          end

          it "bumps the topic if the setting is disabled" do
            SiteSetting.disable_category_edit_notifications = false
            last_bumped_at = topic.bumped_at
            expect(last_bumped_at).not_to be_nil

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }
            end.to change { topic.reload.category_id }.to(category.id)

            expect(response.status).to eq(200)
            expect(topic.reload.bumped_at).not_to eq_time(last_bumped_at)
          end
        end

        context "when using SiteSetting.disable_tags_edit_notifications" do
          fab!(:t1) { Fabricate(:tag) }
          fab!(:t2) { Fabricate(:tag) }
          let(:tags) { [t1, t2] }

          it "doesn't bump the topic if the setting is enabled" do
            SiteSetting.disable_tags_edit_notifications = true
            last_bumped_at = topic.bumped_at
            expect(last_bumped_at).not_to be_nil

            put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: tags.map(&:name) }

            expect(topic.reload.tags).to match_array(tags)
            expect(response.status).to eq(200)
            expect(topic.reload.bumped_at).to eq_time(last_bumped_at)
          end

          it "bumps the topic if the setting is disabled" do
            SiteSetting.disable_tags_edit_notifications = false
            last_bumped_at = topic.bumped_at
            expect(last_bumped_at).not_to be_nil

            put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: tags.map(&:name) }

            expect(topic.reload.tags).to match_array(tags)
            expect(response.status).to eq(200)
            expect(topic.reload.bumped_at).not_to eq_time(last_bumped_at)
          end
        end

        describe "when first post is locked" do
          it "blocks non-staff from editing even if 'trusted_users_can_edit_others' is true" do
            SiteSetting.trusted_users_can_edit_others = true
            user.update!(trust_level: 3)
            topic.first_post.update!(locked_by_id: admin.id)

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              title: topic.title + " hello"
            }

            expect(response.status).to eq(403)
          end

          it "allows staff to edit" do
            sign_in(Fabricate(:admin))
            topic.first_post.update!(locked_by_id: admin.id)

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              title: topic.title + " hello"
            }
            expect(response.status).to eq(200)
          end
        end

        context 'tags' do
          before do
            SiteSetting.tagging_enabled = true
          end

          it "can add a tag to topic" do
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                tags: [tag.name]
              }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)
          end

          it "can create a tag" do
            SiteSetting.min_trust_to_create_tag = 0
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                tags: ["newtag"]
              }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.reload.tags.pluck(:name)).to contain_exactly("newtag")
          end

          it "can change the category and create a new tag" do
            SiteSetting.min_trust_to_create_tag = 0
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                tags: ["newtag"],
                category_id: category.id
              }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.reload.tags.pluck(:name)).to contain_exactly("newtag")
          end

          it "can add a tag to wiki topic" do
            SiteSetting.min_trust_to_edit_wiki_post = 2
            topic.first_post.update!(wiki: true)
            sign_in(user_2)

            expect do
              put "/t/#{topic.id}/tags.json", params: {
                tags: [tag.name]
              }
            end.not_to change { topic.reload.first_post.revisions.count }

            expect(response.status).to eq(403)
            user_2.update!(trust_level: 2)

            expect do
              put "/t/#{topic.id}/tags.json", params: {
                tags: [tag.name]
              }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)
          end

          it 'does not remove tag if no params is given' do
            topic.tags << tag

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json"
            end.to_not change { topic.reload.tags.count }

            expect(response.status).to eq(200)
          end

          it 'can remove a tag' do
            topic.tags << tag

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                tags: [""]
              }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags).to eq([])
          end

          it 'does not cause a revision when tags have not changed' do
            topic.tags << tag

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: {
                tags: [tag.name]
              }
            end.to change { topic.reload.first_post.revisions.count }.by(0)

            expect(response.status).to eq(200)
          end
        end

        context 'when topic is private' do
          before do
            topic.update!(
              archetype: Archetype.private_message,
              category: nil,
              allowed_users: [topic.user]
            )
          end

          context 'when there are no changes' do
            it 'does not call the PostRevisor' do
              expect do
                put "/t/#{topic.slug}/#{topic.id}.json", params: {
                  category_id: topic.category_id
                }
              end.not_to change(PostRevision.all, :count)

              expect(response.status).to eq(200)
            end
          end
        end

        context 'updating to a category with restricted tags' do
          fab!(:restricted_category) { Fabricate(:category) }
          fab!(:tag1) { Fabricate(:tag) }
          fab!(:tag2) { Fabricate(:tag) }
          fab!(:tag3) { Fabricate(:tag) }
          fab!(:tag_group_1) { Fabricate(:tag_group, tag_names: [tag1.name]) }
          fab!(:tag_group_2) { Fabricate(:tag_group) }

          before_all do
            SiteSetting.tagging_enabled = true
            topic.update!(tags: [tag1])
          end

          it 'can’t change to a category disallowing this topic current tags' do
            restricted_category.allowed_tags = [tag2.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

            result = response.parsed_body

            expect(response.status).to eq(422)
            expect(result['errors']).to be_present
            expect(topic.reload.category_id).not_to eq(restricted_category.id)
          end

          it 'can’t change to a category disallowing this topic current tag (through tag_group)' do
            tag_group_2.tags = [tag2]
            restricted_category.allowed_tag_groups = [tag_group_2.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

            result = response.parsed_body

            expect(response.status).to eq(422)
            expect(result['errors']).to be_present
            expect(topic.reload.category_id).not_to eq(restricted_category.id)
          end

          it 'can change to a category allowing this topic current tags' do
            restricted_category.allowed_tags = [tag1.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

            expect(response.status).to eq(200)
          end

          it 'can change to a category allowing this topic current tags (through tag_group)' do
            tag_group_1.tags = [tag1]
            restricted_category.allowed_tag_groups = [tag_group_1.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

            expect(response.status).to eq(200)
          end

          it 'can change to a category allowing any tag' do
            put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }

            expect(response.status).to eq(200)
          end

          it 'can’t add a category-only tags from another category to a category' do
            restricted_category.allowed_tags = [tag2.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              tags: [tag2.name],
              category_id: category.id
            }

            result = response.parsed_body
            expect(response.status).to eq(422)
            expect(result['errors']).to be_present
            expect(result['errors'][0]).to include(tag2.name)
            expect(topic.reload.category_id).not_to eq(restricted_category.id)
          end

          it 'allows category change when topic has a hidden tag' do
            Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag1.name])

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: category.id
            }

            result = response.parsed_body
            expect(response.status).to eq(200)
            expect(topic.reload.tags).to include(tag1)
          end

          it 'allows category change when topic has a read-only tag' do
            Fabricate(:tag_group, permissions: { "staff" => 1, "everyone" => 3 }, tag_names: [tag3.name])
            topic.update!(tags: [tag3])

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: category.id
            }

            result = response.parsed_body
            expect(response.status).to eq(200)
            expect(topic.reload.tags).to contain_exactly(tag3)
          end

          it 'does not leak tag name when trying to use a staff tag' do
            Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag3.name])

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              tags: [tag3.name],
              category_id: category.id
            }

            result = response.parsed_body
            expect(response.status).to eq(422)
            expect(result['errors']).to be_present
            expect(result['errors'][0]).not_to include(tag3.name)
          end

          it 'will clean tag params' do
            restricted_category.allowed_tags = [tag2.name]

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              tags: [""],
              category_id: restricted_category.id
            }

            result = response.parsed_body
            expect(response.status).to eq(200)
          end
        end

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.allow_uncategorized_topics = false
          end

          it "can add a category to an uncategorized topic" do
            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: category.id
            }

            expect(response.status).to eq(200)
            expect(topic.reload.category).to eq(category)
          end
        end
      end
    end

    describe "featured links" do
      def fabricate_topic(user, category = nil)
        topic = Fabricate(:topic, user: user, category: category)
        Fabricate(:post, user: post_author1, topic: topic)
        topic
      end

      it "allows to update topic featured link" do
        sign_in(trust_level_1)

        tl1_topic = fabricate_topic(trust_level_1)
        put "/t/#{tl1_topic.slug}/#{tl1_topic.id}.json", params: {
          featured_link: "https://discourse.org"
        }

        expect(response.status).to eq(200)
      end

      it "doesn't allow TL0 users to update topic featured link" do
        sign_in(trust_level_0)

        tl0_topic = fabricate_topic(trust_level_0)
        put "/t/#{tl0_topic.slug}/#{tl0_topic.id}.json", params: {
          featured_link: "https://discourse.org"
        }

        expect(response.status).to eq(422)
      end

      it "doesn't allow to update topic featured link if featured links are disabled in settings" do
        sign_in(trust_level_1)

        SiteSetting.topic_featured_link_enabled = false
        tl1_topic = fabricate_topic(trust_level_1)
        put "/t/#{tl1_topic.slug}/#{tl1_topic.id}.json", params: {
          featured_link: "https://discourse.org"
        }

        expect(response.status).to eq(422)
      end

      it "doesn't allow to update topic featured link in the category with forbidden feature links" do
        sign_in(trust_level_1)

        category = Fabricate(:category, topic_featured_link_allowed: false)
        tl1_topic_in_category = fabricate_topic(trust_level_1, category)
        put "/t/#{tl1_topic_in_category.slug}/#{tl1_topic_in_category.id}.json", params: {
          featured_link: "https://discourse.org"
        }

        expect(response.status).to eq(422)
      end
    end
  end

  describe '#show_by_external_id' do
    fab!(:private_topic) { Fabricate(:private_message_topic, external_id: 'private') }
    fab!(:topic) { Fabricate(:topic, external_id: 'asdf') }

    it 'returns 301 when found' do
      get "/t/external_id/asdf.json"
      expect(response.status).to eq(301)
      expect(response).to redirect_to(topic.relative_url + ".json?page=")
    end

    it 'returns right response when not found' do
      get "/t/external_id/fdsa.json"
      expect(response.status).to eq(404)
    end

    describe 'when user does not have access to the topic' do
      it 'should return the right response' do
        sign_in(user)

        get "/t/external_id/private.json"

        expect(response.status).to eq(403)
        expect(response.body).to include(I18n.t('invalid_access'))
      end
    end

  end

  describe '#show' do
    use_redis_snapshotting

    fab!(:private_topic) { pm }
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    fab!(:p1) { Fabricate(:post, user: topic.user) }
    fab!(:p2) { Fabricate(:post, user: topic.user) }

    describe 'when topic is not allowed' do
      it 'should return the right response' do
        SiteSetting.detailed_404 = true
        sign_in(user)

        get "/t/#{private_topic.id}.json"

        expect(response.status).to eq(403)
        expect(response.body).to include(I18n.t('invalid_access'))
      end
    end

    describe 'when topic is allowed to a group' do
      fab!(:group) { Fabricate(:group, public_admission: true) }
      fab!(:category) do
        Fabricate(:category_with_definition).tap do |category|
          category.set_permissions(group => :full)
          category.save!
        end
      end
      fab!(:topic) { Fabricate(:topic, category: category) }

      before do
        SiteSetting.detailed_404 = true
      end

      it 'shows a descriptive error message containing the group name' do
        get "/t/#{topic.id}.json"

        html = CGI.unescapeHTML(response.parsed_body["extras"]["html"])
        expect(response.status).to eq(403)
        expect(html).to include(I18n.t('not_in_group.title_topic', group: group.name))
        expect(html).to include(I18n.t('not_in_group.join_group'))
      end
    end

    it 'correctly renders canonicals' do
      get "/t/#{topic.id}", params: { slug: topic.slug }

      expect(response.status).to eq(200)
      expect(css_select("link[rel=canonical]").length).to eq(1)
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it 'returns 301 even if slug does not match URL' do
      # in the past we had special logic for unlisted topics
      # we would require slug unless you made a json call
      # this was not really providing any security
      #
      # we no longer require a topic be visible to perform url correction
      # if you need to properly hide a topic for users use a secure category
      # or a PM
      Fabricate(:post, user: post_author1, topic: invisible_topic)

      get "/t/#{invisible_topic.id}.json", params: { slug: invisible_topic.slug }
      expect(response.status).to eq(200)

      get "/t/#{topic.id}.json", params: { slug: "just-guessing" }
      expect(response.status).to eq(301)

      get "/t/#{topic.slug}.json"
      expect(response.status).to eq(301)
    end

    it 'shows a topic correctly' do
      get "/t/#{topic.slug}/#{topic.id}.json"
      expect(response.status).to eq(200)
    end

    it 'return 404 for an invalid page' do
      get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
      expect(response.status).to eq(404)
    end

    it 'can find a topic given a slug in the id param' do
      get "/t/#{topic.slug}"
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'can find a topic when a slug has a number in front' do
      another_topic = Fabricate(:post, user: post_author1).topic

      topic.update_column(:slug, "#{another_topic.id}-reasons-discourse-is-awesome")
      get "/t/#{another_topic.id}-reasons-discourse-is-awesome"

      expect(response).to redirect_to(topic.relative_url)
    end

    it 'keeps the post_number parameter around when redirecting' do
      get "/t/#{topic.slug}", params: { post_number: 42 }
      expect(response).to redirect_to(topic.relative_url + "/42")
    end

    it 'keeps the page around when redirecting' do
      get "/t/#{topic.slug}", params: {
        post_number: 42, page: 123
      }

      expect(response).to redirect_to(topic.relative_url + "/42?page=123")
    end

    it 'does not accept page params as an array' do
      get "/t/#{topic.slug}", params: {
        post_number: 42, page: [2]
      }

      expect(response).to redirect_to("#{topic.relative_url}/42?page=1")
    end

    it 'returns 404 when an invalid slug is given and no id' do
      get "/t/nope-nope.json"

      expect(response.status).to eq(404)
    end

    it 'returns a 404 when slug and topic id do not match a topic' do
      get "/t/made-up-topic-slug/123456.json"
      expect(response.status).to eq(404)
    end

    it 'returns a 404 for an ID that is larger than postgres limits' do
      get "/t/made-up-topic-slug/5014217323220164041.json"

      expect(response.status).to eq(404)
    end

    context 'a topic with nil slug exists' do
      before do
        nil_slug_topic = Fabricate(:topic)
        Topic.connection.execute("update topics set slug=null where id = #{nil_slug_topic.id}") # can't find a way to set slug column to null using the model
      end

      it 'returns a 404 when slug and topic id do not match a topic' do
        get "/t/made-up-topic-slug/123123.json"
        expect(response.status).to eq(404)
      end
    end

    context 'permission errors' do
      fab!(:allowed_user) { Fabricate(:user) }
      fab!(:allowed_group) { Fabricate(:group) }
      fab!(:accessible_group) { Fabricate(:group, public_admission: true) }
      fab!(:secure_category) do
        c = Fabricate(:category)
        c.permissions = [[allowed_group, :full]]
        c.save
        allowed_user.groups = [allowed_group]
        allowed_user.save
        c
      end
      fab!(:accessible_category) do
        Fabricate(:category).tap do |c|
          c.set_permissions(accessible_group => :full)
          c.save!
        end
      end
      fab!(:normal_topic) { Fabricate(:topic) }
      fab!(:secure_topic) { Fabricate(:topic, category: secure_category) }
      fab!(:private_topic) { Fabricate(:private_message_topic, user: allowed_user) }

      # Can't use fab!, because deleted_topics can't be re-found
      before_all do
        @deleted_topic = Fabricate(:deleted_topic)
        @deleted_secure_topic = Fabricate(:topic, category: secure_category, deleted_at: 1.day.ago)
        @deleted_private_topic = Fabricate(:private_message_topic, user: allowed_user, deleted_at: 1.day.ago)
      end
      let(:deleted_topic) { @deleted_topic }
      let(:deleted_secure_topic) { @deleted_secure_topic }
      let(:deleted_private_topic) { @deleted_private_topic }

      let!(:nonexistent_topic_id) { Topic.last.id + 10000 }
      fab!(:secure_accessible_topic) { Fabricate(:topic, category: accessible_category) }

      shared_examples "various scenarios" do |expected, request_json:|
        expected.each do |key, value|
          it "returns #{value} for #{key}" do
            slug = key == :nonexistent ? "garbage-slug" : send(key.to_s).slug
            topic_id = key == :nonexistent ? nonexistent_topic_id : send(key.to_s).id
            format = request_json ? ".json" : ""
            get "/t/#{slug}/#{topic_id}#{format}"
            expect(response.status).to eq(value)
          end
        end

        expected_slug_response = expected[:secure_topic] == 200 ? 301 : expected[:secure_topic]
        it "will return a #{expected_slug_response} when requesting a secure topic by slug" do
          format = request_json ? ".json" : ""
          get "/t/#{secure_topic.slug}#{format}"
          expect(response.status).to eq(expected_slug_response)
        end
      end

      context 'without detailed error pages' do
        before do
          SiteSetting.detailed_404 = false
        end

        context 'anonymous' do
          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'anonymous with login required' do
          before do
            SiteSetting.login_required = true
          end
          expected = {
            normal_topic: 302,
            secure_topic: 302,
            private_topic: 302,
            deleted_topic: 302,
            deleted_secure_topic: 302,
            deleted_private_topic: 302,
            nonexistent: 302,
            secure_accessible_topic: 302
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'anonymous with login required, requesting json' do
          before do
            SiteSetting.login_required = true
          end
          expected = {
            normal_topic: 403,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 403,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 403,
            secure_accessible_topic: 403
          }
          include_examples "various scenarios", expected, request_json: true
        end

        context 'normal user' do
          before do
            sign_in(user)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'allowed user' do
          before do
            sign_in(allowed_user)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'moderator' do
          before do
            sign_in(moderator)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 200,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'admin' do
          before do
            sign_in(admin)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 200,
            deleted_secure_topic: 200,
            deleted_private_topic: 200,
            nonexistent: 404,
            secure_accessible_topic: 200
          }
          include_examples "various scenarios", expected, request_json: false
        end
      end

      context 'with detailed error pages' do
        before do
          SiteSetting.detailed_404 = true
        end

        context 'anonymous' do
          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 410,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403
          }
          include_examples "various scenarios", expected, request_json: true
        end

        context 'anonymous with login required' do
          before do
            SiteSetting.login_required = true
          end
          expected = {
            normal_topic: 302,
            secure_topic: 302,
            private_topic: 302,
            deleted_topic: 302,
            deleted_secure_topic: 302,
            deleted_private_topic: 302,
            nonexistent: 302,
            secure_accessible_topic: 302
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'normal user' do
          before do
            sign_in(user)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 410,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403
          }
          include_examples "various scenarios", expected, request_json: true
        end

        context 'allowed user' do
          before do
            sign_in(allowed_user)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 410,
            deleted_secure_topic: 410,
            deleted_private_topic: 410,
            nonexistent: 404,
            secure_accessible_topic: 403
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'moderator' do
          before do
            sign_in(moderator)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 200,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403
          }
          include_examples "various scenarios", expected, request_json: false
        end

        context 'admin' do
          before do
            sign_in(admin)
          end

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 200,
            deleted_secure_topic: 200,
            deleted_private_topic: 200,
            nonexistent: 404,
            secure_accessible_topic: 200
          }
          include_examples "various scenarios", expected, request_json: false
        end
      end

    end

    it 'records a view' do
      expect do
        get "/t/#{topic.slug}/#{topic.id}.json"
      end.to change(TopicViewItem, :count).by(1)
    end

    it 'records a view to invalid post_number' do
      expect do
        get "/t/#{topic.slug}/#{topic.id}/#{256**4}", params: {
          u: user.username
        }
        expect(response.status).to eq(200)
      end.to change { IncomingLink.count }.by(1)

    end

    it 'records incoming links' do
      expect do
        get "/t/#{topic.slug}/#{topic.id}", params: {
          u: user.username
        }
      end.to change { IncomingLink.count }.by(1)
    end

    context 'print' do
      it "doesn't renders the print view when disabled" do
        SiteSetting.max_prints_per_hour_per_user = 0

        get "/t/#{topic.slug}/#{topic.id}/print"

        expect(response).to be_forbidden
      end

      it 'renders the print view when enabled' do
        SiteSetting.max_prints_per_hour_per_user = 10
        get "/t/#{topic.slug}/#{topic.id}/print", headers: { HTTP_USER_AGENT: "Rails Testing" }

        expect(response.status).to eq(200)
        body = response.body

        expect(body).to have_tag(:body, class: 'crawler')
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
      end

      it "uses the application layout when there's no param" do
        SiteSetting.max_prints_per_hour_per_user = 10
        get "/t/#{topic.slug}/#{topic.id}", headers: { HTTP_USER_AGENT: "Rails Testing" }

        body = response.body

        expect(body).to have_tag(:script, src: '/assets/application.js')
        expect(body).to have_tag(:meta, with: { name: 'fragment' })
      end
    end

    it 'records redirects' do
      get "/t/#{topic.id}", headers: { HTTP_REFERER: "http://twitter.com" }
      get "/t/#{topic.slug}/#{topic.id}", headers: { HTTP_REFERER: nil }

      link = IncomingLink.first
      expect(link.referer).to eq('http://twitter.com')
    end

    it 'tracks a visit for all html requests' do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}"
      topic_user = TopicUser.where(user: user, topic: topic).first
      expect(topic_user.last_visited_at).to eq_time(topic_user.first_visited_at)
    end

    context 'consider for a promotion' do
      before do
        SiteSetting.tl1_requires_topics_entered = 0
        SiteSetting.tl1_requires_read_posts = 0
        SiteSetting.tl1_requires_time_spent_mins = 0
        SiteSetting.tl1_requires_time_spent_mins = 0
      end

      it "reviews the user for a promotion if they're new" do
        sign_in(user)
        user.update_column(:trust_level, TrustLevel[0])
        get "/t/#{topic.slug}/#{topic.id}.json"
        user.reload
        expect(user.trust_level).to eq(1)
      end
    end

    context 'filters' do
      def extract_post_stream
        json = response.parsed_body
        json["post_stream"]["posts"].map { |post| post["id"] }
      end

      before do
        TopicView.stubs(:chunk_size).returns(2)
        @post_ids = topic.posts.pluck(:id)
        3.times do
          @post_ids << Fabricate(:post, user: post_author1, topic: topic).id
        end
      end

      it 'grabs the correct set of posts' do
        get "/t/#{topic.slug}/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[0..1])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[0..1])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[2..3])

        post_number = topic.posts.pluck(:post_number).sort[3]
        get "/t/#{topic.slug}/#{topic.id}/#{post_number}.json"
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[-2..-1])

        TopicView.stubs(:chunk_size).returns(3)

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[0..2])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[3..3])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 3 }
        expect(response.status).to eq(404)

        TopicView.stubs(:chunk_size).returns(4)

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(@post_ids[0..3])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response.status).to eq(404)
      end
    end

    describe '#show filters' do
      fab!(:post) { Fabricate(:post, user: post_author1) }
      fab!(:topic) { post.topic }
      fab!(:post2) { Fabricate(:post, user: post_author2, topic: topic) }

      describe 'filter by replies to a post' do
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic, reply_to_post_number: post2.post_number) }
        fab!(:post4) { Fabricate(:post, user: post_author4, topic: topic, reply_to_post_number: post2.post_number) }
        fab!(:post5) { Fabricate(:post, user: post_author5, topic: topic) }
        fab!(:quote_reply) { Fabricate(:basic_reply, user: user, topic: topic) }
        fab!(:post_reply) { PostReply.create(post_id: post2.id, reply_post_id: quote_reply.id) }

        it 'should return the right posts' do
          get "/t/#{topic.id}.json", params: {
            replies_to_post_number: post2.post_number
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body.has_key?("suggested_topics")).to eq(false)
          expect(body.has_key?("related_messages")).to eq(false)

          ids = body["post_stream"]["posts"].map { |p| p["id"] }
          expect(ids).to eq([post.id, post2.id, post3.id, post4.id, quote_reply.id])
        end
      end

      describe 'filter upwards by post id' do
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic) }
        fab!(:post4) { Fabricate(:post, user: post_author4, topic: topic, reply_to_post_number: post3.post_number) }
        fab!(:post5) { Fabricate(:post, user: post_author5, topic: topic, reply_to_post_number: post4.post_number) }
        fab!(:post6) { Fabricate(:post, user: post_author6, topic: topic) }

        it 'should return the right posts' do
          get "/t/#{topic.id}.json", params: {
            filter_upwards_post_id: post5.id
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body.has_key?("suggested_topics")).to eq(false)
          expect(body.has_key?("related_messages")).to eq(false)

          ids = body["post_stream"]["posts"].map { |p| p["id"] }
          # includes topic OP, current post and subsequent posts
          # but only one level of parents, respecting default max_reply_history = 1
          expect(ids).to eq([post.id, post4.id, post5.id, post6.id])
        end

        it 'should respect max_reply_history site setting' do
          SiteSetting.max_reply_history = 2

          get "/t/#{topic.id}.json", params: {
            filter_upwards_post_id: post5.id
          }

          expect(response.status).to eq(200)

          body = response.parsed_body
          ids = body["post_stream"]["posts"].map { |p| p["id"] }

          # includes 2 levels of replies (post3 and post4)
          expect(ids).to eq([post.id, post3.id, post4.id, post5.id, post6.id])
        end
      end

    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.login_required = true }

      context 'and the user is logged in' do
        before { sign_in(user) }

        it 'shows the topic' do
          get "/t/#{topic.slug}/#{topic.id}.json"
          expect(response.status).to eq(200)
        end
      end

      context 'and the user is not logged in' do
        let(:api_key) { Fabricate(:api_key, user: topic.user) }

        it 'redirects browsers to the login page' do
          get "/t/#{topic.slug}/#{topic.id}"
          expect(response).to redirect_to login_path
        end

        it 'raises a 403 for json requests' do
          get "/t/#{topic.slug}/#{topic.id}.json"
          expect(response.status).to eq(403)
        end

        it 'shows the topic if valid api key is provided' do
          get "/t/#{topic.slug}/#{topic.id}.json", headers: { "HTTP_API_KEY" => api_key.key }

          expect(response.status).to eq(200)
          topic.reload
          expect(topic.views).to eq(1)
        end

        it 'returns 403 for an invalid key' do
          [:json, :html].each do |format|
            get "/t/#{topic.slug}/#{topic.id}.#{format}", headers: { "HTTP_API_KEY" => "bad" }

            expect(response.code.to_i).to eq(403)
            expect(response.body).to include(I18n.t("invalid_access"))
          end
        end
      end
    end

    it "is included for unlisted topics" do
      get "/t/#{invisible_topic.slug}/#{invisible_topic.id}.json"

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
    end

    it "is not included for normal topics" do
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.headers['X-Robots-Tag']).to eq(nil)
    end

    it "is included when allow_index_in_robots_txt is set to false" do
      SiteSetting.allow_index_in_robots_txt = false

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.headers['X-Robots-Tag']).to eq('noindex, nofollow')
    end

    it "doesn't store an incoming link when there's no referer" do
      expect {
        get "/t/#{topic.id}.json"
      }.not_to change(IncomingLink, :count)
      expect(response.status).to eq(200)
    end

    it "doesn't raise an error on a very long link" do
      get "/t/#{topic.id}.json", headers: { HTTP_REFERER: "http://#{'a' * 2000}.com" }
      expect(response.status).to eq(200)
    end

    describe "has_escaped_fragment?" do
      context "when the SiteSetting is disabled" do
        it "uses the application layout even with an escaped fragment param" do
          SiteSetting.enable_escaped_fragments = false

          get "/t/#{topic.slug}/#{topic.id}", params: {
            _escaped_fragment_: 'true'
          }

          body = response.body

          expect(response.status).to eq(200)
          expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
          expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
        end
      end

      context "when the SiteSetting is enabled" do
        before do
          SiteSetting.enable_escaped_fragments = true
        end

        it "uses the application layout when there's no param" do
          get "/t/#{topic.slug}/#{topic.id}"

          body = response.body

          expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
          expect(body).to have_tag(:meta, with: { name: 'fragment' })
        end

        it "uses the crawler layout when there's an _escaped_fragment_ param" do
          get "/t/#{topic.slug}/#{topic.id}", params: {
            _escaped_fragment_: true
          }, headers: { HTTP_USER_AGENT: "Rails Testing" }

          body = response.body

          expect(response.status).to eq(200)
          expect(body).to have_tag(:body, with: { class: 'crawler' })
          expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
        end
      end
    end

    describe 'clear_notifications' do
      it 'correctly clears notifications if specified via cookie' do
        set_subfolder "/eviltrout"

        notification = Fabricate(:notification)
        sign_in(notification.user)

        cookies['cn'] = "2828,100,#{notification.id}"

        get "/t/#{topic.id}.json"

        expect(response.status).to eq(200)
        expect(response.cookies['cn']).to eq(nil)
        expect(response.headers['Set-Cookie']).to match(/^cn=;.*path=\/eviltrout/)

        notification.reload
        expect(notification.read).to eq(true)
      end

      it 'correctly clears notifications if specified via header' do
        notification = Fabricate(:notification)
        sign_in(notification.user)

        get "/t/#{topic.id}.json", headers: { "Discourse-Clear-Notifications" => "2828,100,#{notification.id}" }

        expect(response.status).to eq(200)
        notification.reload
        expect(notification.read).to eq(true)
      end
    end

    describe "read only header" do
      it "returns no read only header by default" do
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.headers['Discourse-Readonly']).to eq(nil)
      end

      it "returns a readonly header if the site is read only" do
        Discourse.received_postgres_readonly!
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.headers['Discourse-Readonly']).to eq('true')
      end
    end

    describe "image only topic" do
      it "uses image alt tag for meta description" do
        post = Fabricate(:post, user: post_author1, raw: "![image_description|690x405](upload://sdtr5O5xaxf0iEOxICxL36YRj86.png)")

        get post.topic.url

        body = response.body
        expect(body).to have_tag(:meta, with: { name: 'description', content: '[image_description]' })
      end

      it "uses image cdn url for schema markup" do
        set_cdn_url("http://cdn.localhost")
        post = Fabricate(:post_with_uploaded_image, user: post_author1)
        cpp = CookedPostProcessor.new(post).update_post_image

        get post.topic.url

        body = response.body
        expect(body).to have_tag(:link, with: { itemprop: 'image', href: post.image_url })
      end
    end
  end

  describe '#post_ids' do
    fab!(:post) { Fabricate(:post, user: post_author1) }
    fab!(:topic) { post.topic }

    before do
      TopicView.stubs(:chunk_size).returns(1)
    end

    it 'returns the right post ids' do
      post2 = Fabricate(:post, user: post_author2, topic: topic)
      post3 = Fabricate(:post, user: post_author3, topic: topic)

      get "/t/#{topic.id}/post_ids.json", params: {
        post_number: post.post_number
      }

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["post_ids"]).to eq([post2.id, post3.id])
    end

    describe 'filtering by post number with filters' do
      describe 'username filters' do
        fab!(:post) { Fabricate(:post, user: user) }
        fab!(:post2) { Fabricate(:post, topic: topic, user: user) }
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic) }

        it 'should return the right posts' do
          get "/t/#{topic.id}/post_ids.json", params: {
            post_number: post.post_number,
            username_filters: post2.user.username
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["post_ids"]).to eq([post2.id])
        end
      end

      describe 'summary filter' do
        fab!(:post2) { Fabricate(:post, user: post_author2, topic: topic, percent_rank: 0.2) }
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic) }

        it 'should return the right posts' do
          get "/t/#{topic.id}/post_ids.json", params: {
            post_number: post.post_number,
            filter: 'summary'
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["post_ids"]).to eq([post2.id])
        end
      end

      describe 'custom filters' do
        fab!(:post2) { Fabricate(:post, user: post_author2, topic: topic, percent_rank: 0.2) }
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic, percent_rank: 0.5) }
        it 'should return the right posts' do
          TopicView.add_custom_filter("percent") do |posts, topic_view|
            posts.where(percent_rank: 0.5)
          end

          get "/t/#{topic.id}.json", params: {
            post_number: post.post_number,
            filter: 'percent'
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["post_stream"]["posts"].map { |p| p["id"] }).to eq([post3.id])
        ensure
          TopicView.instance_variable_set(:@custom_filters, {})
        end
      end
    end
  end

  describe '#posts' do
    fab!(:post) { Fabricate(:post, user: post_author1) }
    fab!(:topic) { post.topic }

    after do
      Discourse.redis.flushdb
    end

    it 'returns first post of the topic' do
      # we need one for suggested
      create_post

      get "/t/#{topic.id}/posts.json"

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["post_stream"]["posts"].first["id"]).to eq(post.id)

      expect(body["suggested_topics"]).to eq(nil)

      get "/t/#{topic.id}/posts.json?include_suggested=true"
      body = response.parsed_body

      expect(body["suggested_topics"]).not_to eq(nil)
    end

    describe 'filtering by post number with filters' do
      describe 'username filters' do
        fab!(:post2) { Fabricate(:post, user: post_author2, topic: topic) }
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic) }

        it 'should return the right posts' do
          TopicView.stubs(:chunk_size).returns(2)

          get "/t/#{topic.id}/posts.json", params: {
            post_number: post.post_number,
            username_filters: post2.user.username,
            asc: true
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["post_stream"]["posts"].first["id"]).to eq(post2.id)
        end
      end

      describe 'summary filter' do
        fab!(:post2) { Fabricate(:post, user: post_author2, topic: topic, percent_rank: 0.2) }
        fab!(:post3) { Fabricate(:post, user: post_author3, topic: topic) }

        it 'should return the right posts' do
          TopicView.stubs(:chunk_size).returns(2)

          get "/t/#{topic.id}/posts.json", params: {
            post_number: post.post_number,
            filter: 'summary',
            asc: true
          }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["post_stream"]["posts"].first["id"]).to eq(post2.id)
        end
      end
    end
  end

  describe '#feed' do
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it 'renders rss of the topic' do
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq('application/rss+xml')
    end

    it 'renders rss of the topic correctly with subfolder' do
      set_subfolder "/forum"
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("/forum/forum")
      expect(response.body).to include("http://test.localhost/forum/t/#{topic.slug}")
    end

    it 'returns 404 when posts are deleted' do
      topic.posts.each(&:trash!)
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(404)
    end

    it 'returns 404 when the topic is deleted' do
      topic.trash!
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(404)
    end
  end

  describe '#invite_notify' do
    it 'does not notify same user multiple times' do
      sign_in(user)

      expect { post "/t/#{topic.id}/invite-notify.json", params: { usernames: [user_2.username] } }
        .to change { Notification.count }.by(1)
      expect(response.status).to eq(200)

      expect { post "/t/#{topic.id}/invite-notify.json", params: { usernames: [user_2.username] } }
        .to change { Notification.count }.by(0)
      expect(response.status).to eq(200)

      freeze_time 1.day.from_now

      expect { post "/t/#{topic.id}/invite-notify.json", params: { usernames: [user_2.username] } }
        .to change { Notification.count }.by(1)
      expect(response.status).to eq(200)
    end

    it 'does not let regular users to notify multiple users' do
      sign_in(user)

      expect { post "/t/#{topic.id}/invite-notify.json", params: { usernames: [admin.username, user_2.username] } }
        .to change { Notification.count }.by(0)
      expect(response.status).to eq(400)
    end

    it 'lets staff to notify multiple users' do
      sign_in(admin)

      expect { post "/t/#{topic.id}/invite-notify.json", params: { usernames: [user.username, user_2.username] } }
        .to change { Notification.count }.by(2)
      expect(response.status).to eq(200)
    end
  end

  describe '#invite_group' do
    let!(:admins) { Group[:admins] }

    before do
      sign_in(admin)
      admins.messageable_level = Group::ALIAS_LEVELS[:everyone]
      admins.save!
    end

    it "disallows inviting a group to a topic" do
      post "/t/#{topic.id}/invite-group.json", params: {
        group: 'admins'
      }

      expect(response.status).to eq(422)
    end

    it "allows inviting a group to a PM" do
      post "/t/#{pm.id}/invite-group.json", params: {
        group: 'admins'
      }

      expect(response.status).to eq(200)
      expect(pm.allowed_groups.first.id).to eq(admins.id)
    end
  end

  describe '#make_banner' do
    it 'needs you to be a staff member' do
      tl4_topic = Fabricate(:topic, user: sign_in(trust_level_4))
      put "/t/#{tl4_topic.id}/make-banner.json"
      expect(response).to be_forbidden
    end

    describe 'when logged in' do
      it "changes the topic archetype to 'banner'" do
        admin_topic = Fabricate(:topic, user: sign_in(admin))

        put "/t/#{admin_topic.id}/make-banner.json"
        expect(response.status).to eq(200)
        admin_topic.reload
        expect(admin_topic.archetype).to eq(Archetype.banner)
      end
    end
  end

  describe '#remove_banner' do
    it 'needs you to be a staff member' do
      tl4_topic = Fabricate(:topic, user: sign_in(trust_level_4), archetype: Archetype.banner)
      put "/t/#{tl4_topic.id}/remove-banner.json"
      expect(response).to be_forbidden
    end

    describe 'when logged in' do
      it "resets the topic archetype" do
        admin_topic = Fabricate(:topic, user: sign_in(admin), archetype: Archetype.banner)

        put "/t/#{admin_topic.id}/remove-banner.json"
        expect(response.status).to eq(200)
        admin_topic.reload
        expect(admin_topic.archetype).to eq(Archetype.default)
      end
    end
  end

  describe '#remove_allowed_user' do
    it 'admin can be removed from a pm' do
      sign_in(admin)
      pm = create_post(user: user, archetype: 'private_message', target_usernames: [user.username, admin.username])

      put "/t/#{pm.topic_id}/remove-allowed-user.json", params: {
        username: admin.username
      }

      expect(response.status).to eq(200)
      expect(TopicAllowedUser.where(topic_id: pm.topic_id, user_id: admin.id).first).to eq(nil)
    end
  end

  describe '#bulk' do
    it 'needs you to be logged in' do
      put "/topics/bulk.json"
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      before { sign_in(user) }
      let!(:operation) { { type: 'change_category', category_id: '1' } }
      let!(:topic_ids) { [1, 2, 3] }

      it "requires a list of topic_ids or filter" do
        put "/topics/bulk.json", params: { operation: operation }
        expect(response.status).to eq(400)
      end

      it "requires an operation param" do
        put "/topics/bulk.json", params: { topic_ids: topic_ids }
        expect(response.status).to eq(400)
      end

      it "requires a type field for the operation param" do
        put "/topics/bulk.json", params: { topic_ids: topic_ids, operation: {} }
        expect(response.status).to eq(400)
      end

      it "can mark sub-categories unread" do
        sub = Fabricate(:category, parent_category_id: category.id)

        topic.update!(category_id: sub.id)

        post1 = create_post(user: user, topic_id: topic.id)
        create_post(topic_id: topic.id)

        put "/topics/bulk.json", params: {
          category_id: category.id,
          include_subcategories: true,
          filter: 'unread',
          operation: { type: 'dismiss_posts' }
        }

        expect(response.status).to eq(200)
        expect(TopicUser.get(post1.topic, post1.user).last_read_post_number).to eq(2)
      end

      it "can mark tag topics unread" do
        TopicTag.create!(
          topic_id: topic.id,
          tag_id: tag.id
        )

        post1 = create_post(user: user, topic_id: topic.id)
        create_post(topic_id: topic.id)

        put "/topics/bulk.json", params: {
          tag_name: tag.name,
          filter: 'unread',
          operation: { type: 'dismiss_posts' }
        }

        expect(response.status).to eq(200)
        expect(TopicUser.get(post1.topic, post1.user).last_read_post_number).to eq(2)
      end

      context "private message" do

        fab!(:group) do
          Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
            g.add(user_2)
          end
        end

        fab!(:group_message) do
          create_post(
            user: user,
            target_group_names: [group.name],
            archetype: Archetype.private_message
          ).topic
        end

        fab!(:private_message) do
          create_post(
            user: user,
            target_usernames: [user_2.username],
            archetype: Archetype.private_message
          ).topic
        end

        fab!(:private_message_2) do
          create_post(
            user: user,
            target_usernames: [user_2.username],
            archetype: Archetype.private_message
          ).topic
        end

        fab!(:group_pm_topic_user) do
          TopicUser.find_by(user: user_2, topic: group_message).tap do |tu|
            tu.update!(last_read_post_number: 1)
          end
        end

        fab!(:regular_pm_topic_user) do
          TopicUser.find_by(user: user_2, topic: private_message).tap do |tu|
            tu.update!(last_read_post_number: 1)
          end
        end

        fab!(:regular_pm_topic_user_2) do
          TopicUser.find_by(user: user_2, topic: private_message_2).tap do |tu|
            tu.update!(last_read_post_number: 1)
          end
        end

        before_all do
          create_post(user: user, topic: group_message)
          create_post(user: user, topic: private_message)
          create_post(user: user, topic: private_message_2)
        end

        before do
          sign_in(user_2)
        end

        it "can dismiss all user and group private message topics" do
          expect do
            put "/topics/bulk.json", params: {
              filter: "unread",
              operation: { type: 'dismiss_posts' },
              private_message_inbox: "all"
            }

            expect(response.status).to eq(200)
          end.to change { group_pm_topic_user.reload.last_read_post_number }.from(1).to(2)
            .and change { regular_pm_topic_user.reload.last_read_post_number }.from(1).to(2)
        end

        it "can dismiss all user unread private message topics" do
          stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 1) do
            expect do
              put "/topics/bulk.json", params: {
                filter: "unread",
                operation: { type: 'dismiss_posts' },
                private_message_inbox: "user"
              }

              expect(response.status).to eq(200)
            end.to change { regular_pm_topic_user.reload.last_read_post_number }.from(1).to(2)
              .and change { regular_pm_topic_user_2.reload.last_read_post_number }.from(1).to(2)

            expect(group_pm_topic_user.reload.last_read_post_number).to eq(1)
          end
        end

        it "returns the right response when trying to dismiss private messages of an invalid group" do
          put "/topics/bulk.json", params: {
            filter: "unread",
            operation: { type: 'dismiss_posts' },
            private_message_inbox: "group",
            group_name: 'randomgroup'
          }

          expect(response.status).to eq(404)
        end

        it "returns the right response when trying to dismiss private messages of a restricted group" do
          sign_in(user)

          put "/topics/bulk.json", params: {
            filter: "unread",
            operation: { type: 'dismiss_posts' },
            private_message_inbox: "group",
            group_name: group.name
          }

          expect(response.status).to eq(404)
        end

        it "can dismiss all group unread private message topics" do
          expect do
            put "/topics/bulk.json", params: {
              filter: "unread",
              operation: { type: 'dismiss_posts' },
              private_message_inbox: "group",
              group_name: group.name
            }

            expect(response.status).to eq(200)
          end.to change { group_pm_topic_user.reload.last_read_post_number }.from(1).to(2)

          expect(regular_pm_topic_user.reload.last_read_post_number).to eq(1)
        end
      end

      it "can find unread" do
        # mark all unread muted
        put "/topics/bulk.json", params: {
          filter: 'unread', operation: { type: :change_notification_level, notification_level_id: 0 }
        }

        expect(response.status).to eq(200)
      end

      it "delegates work to `TopicsBulkAction`" do
        topics_bulk_action = mock
        TopicsBulkAction.expects(:new).with(user, topic_ids, operation, group: nil).returns(topics_bulk_action)
        topics_bulk_action.expects(:perform!)

        put "/topics/bulk.json", params: {
          topic_ids: topic_ids, operation: operation
        }
      end

      it "raises an error if topic_ids is provided and it is not an array" do
        put "/topics/bulk.json", params: {
          topic_ids: "1", operation: operation
        }
        expect(response.parsed_body["errors"].first).to match(/Expecting topic_ids to contain a list/)
        put "/topics/bulk.json", params: {
          topic_ids: [1], operation: operation
        }
        expect(response.parsed_body["errors"]).to eq(nil)
      end

      it "respects the tracked parameter" do
        # untracked topic
        CategoryUser.set_notification_level_for_category(user,
                                                     NotificationLevels.all[:regular],
                                                     category.id)
        create_post(user: user, topic_id: topic.id)
        topic.update!(category_id: category.id)
        create_post(topic_id: topic.id)

        # tracked topic
        CategoryUser.set_notification_level_for_category(user,
                                                     NotificationLevels.all[:tracking],
                                                     tracked_category.id)
        tracked_topic = create_post(user: user).topic
        tracked_topic.update!(category_id: tracked_category.id)
        create_post(topic_id: tracked_topic.id)

        put "/topics/bulk.json", params: {
          filter: 'unread',
          operation: { type: 'dismiss_posts' },
          tracked: true
        }

        expect(response.status).to eq(200)
        expect(TopicUser.get(topic, user).last_read_post_number).to eq(topic.posts.count - 1)
        expect(TopicUser.get(tracked_topic, user).last_read_post_number).to eq(tracked_topic.posts.count)
      end
    end
  end

  describe '#remove_bookmarks' do
    it "should remove bookmarks properly from non first post" do
      sign_in(user)

      post = create_post
      post2 = create_post(topic_id: post.topic_id)
      Fabricate(:bookmark, user: user, post: post)
      Fabricate(:bookmark, user: user, post: post2)

      put "/t/#{post.topic_id}/remove_bookmarks.json"
      expect(Bookmark.where(user: user).count).to eq(0)
    end

    it "should disallow bookmarks on posts you have no access to" do
      sign_in(Fabricate(:user))
      pm = create_post(user: user, archetype: 'private_message', target_usernames: [user.username])

      put "/t/#{pm.topic_id}/bookmark.json"
      expect(response).to be_forbidden
    end

    context "bookmarks with reminders" do
      it "deletes all the bookmarks for the user in the topic" do
        sign_in(user)
        post = create_post
        Fabricate(:bookmark, post: post, user: user)
        put "/t/#{post.topic_id}/remove_bookmarks.json"
        expect(Bookmark.for_user_in_topic(user.id, post.topic_id).count).to eq(0)
      end
    end
  end

  describe "#bookmark" do
    before do
      sign_in(user)
    end

    it "should create a new bookmark on the first post of the topic" do
      post = create_post
      post2 = create_post(topic_id: post.topic_id)
      put "/t/#{post.topic_id}/bookmark.json"

      expect(Bookmark.find_by(user_id: user.id).post_id).to eq(post.id)
    end

    it "errors if the topic is already bookmarked for the user" do
      post = create_post
      Bookmark.create(post: post, user: user)

      put "/t/#{post.topic_id}/bookmark.json"
      expect(response.status).to eq(400)
    end

    context "bookmarks with reminders" do
      it "should create a new bookmark on the first post of the topic" do
        post = create_post
        post2 = create_post(topic_id: post.topic_id)
        put "/t/#{post.topic_id}/bookmark.json"
        expect(response.status).to eq(200)

        bookmarks_for_topic = Bookmark.for_user_in_topic(user.id, post.topic_id)
        expect(bookmarks_for_topic.count).to eq(1)
        expect(bookmarks_for_topic.first.post_id).to eq(post.id)
      end

      it "errors if the topic is already bookmarked for the user" do
        post = create_post
        Bookmark.create(post: post, user: user)

        put "/t/#{post.topic_id}/bookmark.json"
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#reset_new' do
    context "when a user is not signed in" do
      it 'fails' do
        put "/topics/reset-new.json"
        expect(response.status).to eq(403)
      end
    end

    context "when a user is signed in" do
      before_all do
        @old_date = 2.years.ago
        user.user_stat.update_column(:new_since, @old_date)

        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:tracking],
          tracked_category.id,
        )
      end

      let!(:old_date) { @old_date }

      before do
        sign_in(user)
      end

      context "when tracked is unset" do
        it "updates the `new_since` date" do
          TopicTrackingState.expects(:publish_dismiss_new)

          put "/topics/reset-new.json"
          expect(response.status).to eq(200)
          user.reload
          expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)
        end
      end

      describe "when tracked param is true" do
        it "does not update user_stat.new_since" do
          put "/topics/reset-new.json?tracked=true"
          expect(response.status).to eq(200)
          user.reload
          expect(user.user_stat.new_since.to_date).to eq(old_date.to_date)
        end

        it "creates dismissed topic user records for each new topic" do
          tracked_topic = create_post(category: tracked_category).topic

          create_post # This is a new post, but is not tracked so a record will not be created for it
          expect do
            put "/topics/reset-new.json?tracked=true"
          end.to change {
            DismissedTopicUser.where(user_id: user.id, topic_id: tracked_topic.id).count
          }.by(1)
        end
      end

      context "when 5 tracked topics exist" do
        before_all do
          @tracked_topic_ids = 5.times.map { create_post(category: tracked_category).topic.id }
          @tracked_topic_ids.freeze
        end

        describe "when tracked param is true" do
          it "creates dismissed topic user records if there are > 30 (default pagination) topics" do
            expect do
              stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 2) do
                put "/topics/reset-new.json?tracked=true"
              end
            end.to change {
              DismissedTopicUser.where(user_id: user.id, topic_id: @tracked_topic_ids).count
            }.by(5)
          end

          it "creates dismissed topic user records if there are > 30 (default pagination) topics and topic_ids are provided" do
            dismissing_topic_ids = @tracked_topic_ids.sample(4)

            expect do
              stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 2) do
                put "/topics/reset-new.json?tracked=true", params: { topic_ids: dismissing_topic_ids }
              end
            end.to change {
              DismissedTopicUser.where(user_id: user.id, topic_id: @tracked_topic_ids).count
            }.by(4)
          end
        end

        context "when two extra topics exist" do
          before_all do
            @topic_ids = @tracked_topic_ids + [Fabricate(:topic).id, Fabricate(:topic).id]
            @topic_ids.freeze
          end

          context "when tracked=false" do
            it "updates the user_stat new_since column and dismisses all the new topics" do
              old_new_since = user.user_stat.new_since

              put "/topics/reset-new.json?tracked=false"
              expect(DismissedTopicUser.where(user_id: user.id, topic_id: @topic_ids).count).to eq(7)
              expect(user.reload.user_stat.new_since > old_new_since).to eq(true)
            end

            it "does not pass topic ids that are not new for the user to the bulk action, limit the scope to new topics" do
              dismiss_ids = @topic_ids[0..1]
              other_ids = @topic_ids[2..-1].sort.reverse

              DismissedTopicUser.create(user_id: user.id, topic_id: dismiss_ids.first)
              DismissedTopicUser.create(user_id: user.id, topic_id: dismiss_ids.second)

              expect { put "/topics/reset-new.json?tracked=false" }.to change {
                DismissedTopicUser.where(user_id: user.id).count
              }.by(5)
            end
          end
        end
      end

      context 'category' do
        fab!(:subcategory) { Fabricate(:category, parent_category_id: category.id) }
        fab!(:category_topic) { Fabricate(:topic, category: category) }
        fab!(:subcategory_topic) { Fabricate(:topic, category: subcategory) }

        it 'dismisses topics for main category' do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [category_topic.id])

          put "/topics/reset-new.json?category_id=#{category.id}"

          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([category_topic.id])
        end

        it 'dismisses topics for main category and subcategories' do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [category_topic.id, subcategory_topic.id])

          put "/topics/reset-new.json?category_id=#{category.id}&include_subcategories=true"

          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id).sort).to eq([category_topic.id, subcategory_topic.id].sort)
        end
      end

      context 'tag' do
        fab!(:tag_topic) { Fabricate(:topic) }
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }

        it 'dismisses topics for tag' do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [tag_topic.id])
          put "/topics/reset-new.json?tag_id=#{tag.name}"
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([tag_topic.id])
        end
      end

      context 'tag and category' do
        fab!(:tag_topic) { Fabricate(:topic) }
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }
        fab!(:tag_and_category_topic) { Fabricate(:topic, category: category) }
        fab!(:topic_tag2) { Fabricate(:topic_tag, topic: tag_and_category_topic, tag: tag) }

        it 'dismisses topics for tag' do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [tag_and_category_topic.id])
          put "/topics/reset-new.json?tag_id=#{tag.name}&category_id=#{category.id}"
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([tag_and_category_topic.id])
        end
      end

      context "specific topics" do
        fab!(:topic2) { Fabricate(:topic) }
        fab!(:topic3) { Fabricate(:topic) }

        it "updates the `new_since` date" do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [topic2.id, topic3.id]).at_least_once

          put "/topics/reset-new.json", **{ params: { topic_ids: [topic2.id, topic3.id] } }
          expect(response.status).to eq(200)
          user.reload
          expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to match_array([topic2.id, topic3.id])
        end

        it "raises an error if topic_ids is provided and it is not an array" do
          put "/topics/reset-new.json", params: { topic_ids: topic2.id }
          expect(response.parsed_body["errors"].first).to match(/Expecting topic_ids to contain a list/)
          put "/topics/reset-new.json", params: { topic_ids: [topic2.id] }
          expect(response.parsed_body["errors"]).to eq(nil)
        end

        describe "when tracked param is true" do
          it "does not update user_stat.new_since and does not dismiss untracked topics" do
            put "/topics/reset-new.json?tracked=true", **{ params: { topic_ids: [topic2.id, topic3.id] } }
            expect(response.status).to eq(200)
            user.reload
            expect(user.user_stat.new_since.to_date).to eq(old_date.to_date)
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to be_empty
          end

          it "creates topic user records for each unread topic" do
            tracked_topic = create_post.topic
            tracked_topic.update!(category_id: tracked_category.id)
            topic2.update!(category_id: tracked_category.id)

            create_post # This is a new post, but is not tracked so a record will not be created for it
            expect do
              put "/topics/reset-new.json?tracked=true", **{ params: { topic_ids: [tracked_topic.id, topic2.id, topic3.id] } }
            end.to change { DismissedTopicUser.where(user_id: user.id).count }.by(2)
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to match_array([tracked_topic.id, topic2.id])
          end
        end
      end
    end
  end

  describe '#feature_stats' do
    it "works" do
      get "/topics/feature_stats.json", params: { category_id: 1 }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["pinned_in_category_count"]).to eq(0)
      expect(json["pinned_globally_count"]).to eq(0)
      expect(json["banner_count"]).to eq(0)
    end

    it "allows unlisted banner topic" do
      Fabricate(:topic, category_id: 1, archetype: Archetype.banner, visible: false)

      get "/topics/feature_stats.json", params: { category_id: 1 }
      json = response.parsed_body
      expect(json["banner_count"]).to eq(1)
    end
  end

  describe '#excerpts' do
    it "can correctly get excerpts" do
      first_post = create_post(raw: 'This is the first post :)', title: 'This is a test title I am making yay')
      second_post = create_post(raw: 'This is second post', topic: first_post.topic)
      third_post = first_post.topic.add_small_action(first_post.user, "autobumped")

      random_post = Fabricate(:post, user: post_author1)

      get "/t/#{first_post.topic_id}/excerpts.json", params: {
        post_ids: [first_post.id, second_post.id, third_post.id, random_post.id]
      }

      json = response.parsed_body
      json.sort! { |a, b| a["post_id"] <=> b["post_id"] }

      # no random post
      expect(json.map { |p| p["post_id"] }).to contain_exactly(first_post.id, second_post.id, third_post.id)
      # keep emoji images
      expect(json[0]["excerpt"]).to match(/emoji/)
      expect(json[0]["excerpt"]).to match(/first post/)
      expect(json[0]["username"]).to eq(first_post.user.username)
      expect(json[0]["created_at"].present?).to eq(false)

      expect(json[1]["excerpt"]).to match(/second post/)

      expect(json[2]["action_code"]).to eq("autobumped")
      expect(json[2]["created_at"].present?).to eq(true)
    end
  end

  describe '#convert_topic' do
    it 'needs you to be logged in' do
      put "/t/111/convert-topic/private.json"
      expect(response.status).to eq(403)
    end

    describe 'converting public topic to private message' do
      fab!(:topic) { Fabricate(:topic, user: user) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/private.json"
        expect(response).to be_forbidden
      end

      context "success" do
        it "returns success" do
          sign_in(admin)
          put "/t/#{topic.id}/convert-topic/private.json"

          topic.reload
          expect(topic.archetype).to eq(Archetype.private_message)
          expect(response.status).to eq(200)

          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end

    describe 'converting private message to public topic' do
      fab!(:topic) { Fabricate(:private_message_topic, user: user) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden
      end

      context "success" do
        it "returns success" do
          sign_in(admin)
          put "/t/#{topic.id}/convert-topic/public.json?category_id=#{category.id}"

          topic.reload
          expect(topic.archetype).to eq(Archetype.default)
          expect(topic.category_id).to eq(category.id)
          expect(response.status).to eq(200)

          result = response.parsed_body
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end
  end

  describe '#timings' do
    fab!(:post_1) { Fabricate(:post, user: post_author1, topic: topic) }

    it 'should record the timing' do
      sign_in(user)

      post "/topics/timings.json", params: {
        topic_id: topic.id,
        topic_time: 5,
        timings: { post_1.post_number => 2 }
      }

      expect(response.status).to eq(200)

      post_timing = PostTiming.first

      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2)
    end

    it 'caps post read time at the max integer value (2^31 - 1)' do
      PostTiming.create!(
        topic_id: post_1.topic.id,
        post_number: post_1.post_number,
        user_id: user.id,
        msecs: 2**31 - 10
      )
      sign_in(user)

      post "/topics/timings.json", params: {
        topic_id: topic.id,
        topic_time: 5,
        timings: { post_1.post_number => 100 }
      }

      expect(response.status).to eq(200)
      post_timing = PostTiming.first

      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2**31 - 1)
    end
  end

  describe '#timer' do
    context 'when a user is not logged in' do
      it 'should return the right response' do
        post "/t/#{topic.id}/timer.json", params: {
          time: '24',
          status_type: TopicTimer.types[1]
        }
        expect(response.status).to eq(403)
      end
    end

    context 'when does not have permission' do
      it 'should return the right response' do
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: {
          time: '24',
          status_type: TopicTimer.types[1]
        }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq('invalid_access')
      end
    end

    context 'when time is in the past' do
      it 'returns an error' do
        freeze_time
        sign_in(admin)

        post "/t/#{topic.id}/timer.json", params: {
          time: Time.current - 1.day,
          status_type: TopicTimer.types[1]
        }
        expect(response.status).to eq(400)
      end
    end

    context 'when logged in as an admin' do
      before do
        freeze_time
        sign_in(admin)
      end

      it 'should be able to create a topic status update' do
        post "/t/#{topic.id}/timer.json", params: {
          time: 24,
          status_type: TopicTimer.types[1]
        }

        expect(response.status).to eq(200)

        topic_status_update = TopicTimer.last

        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to eq_time(24.hours.from_now)

        json = response.parsed_body

        expect(DateTime.parse(json['execute_at']))
          .to eq_time(DateTime.parse(topic_status_update.execute_at.to_s))

        expect(json['duration_minutes']).to eq(topic_status_update.duration_minutes)
        expect(json['closed']).to eq(topic.reload.closed)
      end

      it 'should be able to delete a topic status update' do
        Fabricate(:topic_timer, topic: topic)

        post "/t/#{topic.id}/timer.json", params: {
          time: nil,
          status_type: TopicTimer.types[1]
        }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)

        json = response.parsed_body

        expect(json['execute_at']).to eq(nil)
        expect(json['duration_minutes']).to eq(nil)
        expect(json['closed']).to eq(topic.closed)
      end

      it 'should be able to create a topic status update with duration' do
        post "/t/#{topic.id}/timer.json", params: {
          duration_minutes: 7200,
          status_type: TopicTimer.types[7]
        }

        expect(response.status).to eq(200)

        topic_status_update = TopicTimer.last

        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to eq_time(5.days.from_now)
        expect(topic_status_update.duration_minutes).to eq(7200)

        json = response.parsed_body

        expect(DateTime.parse(json['execute_at']))
          .to eq_time(DateTime.parse(topic_status_update.execute_at.to_s))

        expect(json['duration_minutes']).to eq(topic_status_update.duration_minutes)
      end

      it 'should be able to delete a topic status update for delete_replies type' do
        Fabricate(:topic_timer, topic: topic, status_type: TopicTimer.types[:delete_replies])

        post "/t/#{topic.id}/timer.json", params: {
          time: nil,
          status_type: TopicTimer.types[7]
        }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)

        json = response.parsed_body

        expect(json['execute_at']).to eq(nil)
        expect(json['duration']).to eq(nil)
        expect(json['closed']).to eq(topic.closed)
      end

      describe 'publishing topic to category in the future' do
        it 'should be able to create the topic status update' do
          post "/t/#{topic.id}/timer.json", params: {
            time: 24,
            status_type: TopicTimer.types[3],
            category_id: topic.category_id
          }

          expect(response.status).to eq(200)

          topic_status_update = TopicTimer.last

          expect(topic_status_update.topic).to eq(topic)
          expect(topic_status_update.execute_at).to eq_time(24.hours.from_now)
          expect(topic_status_update.status_type)
            .to eq(TopicTimer.types[:publish_to_category])

          json = response.parsed_body

          expect(json['category_id']).to eq(topic.category_id)
        end
      end

      describe 'invalid status type' do
        it 'should raise the right error' do
          post "/t/#{topic.id}/timer.json", params: {
            time: 10,
            status_type: 'something'
          }
          expect(response.status).to eq(400)
          expect(response.body).to include('status_type')
        end
      end
    end

    context 'when logged in as a TL4 user' do
      it "raises an error if the user can't see the topic" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        pm_topic = Fabricate(:private_message_topic)

        post "/t/#{pm_topic.id}/timer.json", params: {
          time: '24',
          status_type: TopicTimer.types[1]
        }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq('invalid_access')
      end
    end
  end

  describe '#set_slow_mode' do
    context 'when not logged in' do
      it 'returns a forbidden response' do
        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600'
        }

        expect(response.status).to eq(403)
      end
    end

    context 'logged in as an admin' do
      it 'allows admins to set the slow mode interval' do
        sign_in(admin)

        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600'
        }

        topic.reload
        expect(response.status).to eq(200)
        expect(topic.slow_mode_seconds).to eq(3600)
      end
    end

    context 'logged in as a regular user' do
      it 'does nothing if the user is not TL4' do
        user.update!(trust_level: TrustLevel[3])
        sign_in(user)

        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600'
        }

        expect(response.status).to eq(403)
      end

      it 'allows TL4 users to set the slow mode interval' do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600'
        }

        topic.reload
        expect(response.status).to eq(200)
        expect(topic.slow_mode_seconds).to eq(3600)
      end
    end

    context 'auto-disable slow mode' do
      before { sign_in(admin) }

      let!(:timestamp) { 1.week.from_now.to_formatted_s(:iso8601) }

      it 'sets a topic timer to clear the slow mode automatically' do
        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600', enabled_until: timestamp
        }

        created_timer = TopicTimer.find_by(topic: topic)
        execute_at = created_timer.execute_at.to_formatted_s(:iso8601)

        expect(execute_at).to eq(timestamp)
      end

      it 'deletes the topic timer' do
        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600', enabled_until: timestamp
        }

        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '0', enabled_until: timestamp
        }

        created_timer = TopicTimer.find_by(topic: topic)

        expect(created_timer).to be_nil
      end

      it 'updates the existing timer' do
        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600', enabled_until: timestamp
        }

        updated_timestamp = 1.hour.from_now.to_formatted_s(:iso8601)

        put "/t/#{topic.id}/slow_mode.json", params: {
          seconds: '3600', enabled_until: updated_timestamp
        }

        created_timer = TopicTimer.find_by(topic: topic)
        execute_at = created_timer.execute_at.to_formatted_s(:iso8601)

        expect(execute_at).to eq(updated_timestamp)
      end
    end
  end

  describe '#invite' do
    describe 'when not logged in' do
      it "should return the right response" do
        post "/t/#{topic.id}/invite.json", params: {
          email: 'jake@adventuretime.ooo'
        }

        expect(response.status).to eq(403)
      end
    end

    describe 'when logged in' do
      before do
        sign_in(user)
      end

      describe 'as a valid user' do
        fab!(:user_topic) { Fabricate(:topic, user: user) }

        it 'should return the right response' do
          user.update!(trust_level: SiteSetting.min_trust_level_to_allow_invite)

          expect do
            post "/t/#{user_topic.id}/invite.json", params: {
              email: 'someguy@email.com'
            }
          end.to change { Invite.where(invited_by_id: user.id).count }.by(1)

          expect(response.status).to eq(200)
          expect(Jobs::InviteEmail.jobs.first['args'].first['invite_to_topic']).to be_truthy
        end
      end

      describe 'when user is a group manager' do
        fab!(:group) { Fabricate(:group).tap { |g| g.add_owner(user) } }
        fab!(:private_category)  { Fabricate(:private_category, group: group) }

        fab!(:group_private_topic) do
          Fabricate(:topic, category: private_category, user: user)
        end

        let!(:recipient) { 'jake@adventuretime.ooo' }

        before_all do
          user.update!(trust_level: SiteSetting.min_trust_level_to_allow_invite)
        end

        it "should attach group to the invite" do
          post "/t/#{group_private_topic.id}/invite.json", params: {
            user: recipient,
            group_ids: "#{group.id},9999999"
          }

          expect(response.status).to eq(200)
          expect(Invite.find_by(email: recipient).groups).to contain_exactly(group)
        end

        describe 'when group is available to automatic groups only' do
          before do
            group.update!(automatic: true)
          end

          it 'should return the right response' do
            post "/t/#{group_private_topic.id}/invite.json", params: {
              user: user
            }

            expect(response.status).to eq(403)
          end
        end

        describe 'when user is not part of the required group' do
          it 'should return the right response' do
            post "/t/#{group_private_topic.id}/invite.json", params: {
              user: user
            }

            expect(response.status).to eq(422)

            response_body = response.parsed_body

            expect(response_body["errors"]).to eq([
              I18n.t("topic_invite.failed_to_invite",
                group_names: group.name
              )
            ])
          end
        end
      end

      describe 'when topic id is invalid' do
        it 'should return the right response' do
          id = topic.id
          topic.destroy!
          post "/t/#{id}/invite.json", params: {
            email: user.email
          }

          expect(response.status).to eq(400)
        end
      end

      it 'requires an email parameter' do
        post "/t/#{topic.id}/invite.json"
        expect(response.status).to eq(400)
      end

      describe "when PM has reached maximum allowed numbers of recipients" do
        fab!(:pm) { Fabricate(:private_message_topic, user: user) }

        fab!(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

        before do
          SiteSetting.max_allowed_message_recipients = 2
        end

        it "doesn't allow normal users to invite" do
          post "/t/#{pm.id}/invite.json", params: {
            user: user_2.username
          }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to contain_exactly(
            I18n.t("pm_reached_recipients_limit", recipients_limit: SiteSetting.max_allowed_message_recipients)
          )
        end

        it "allows staff to bypass limits" do
          sign_in(moderator)
          post "/t/#{moderator_pm.id}/invite.json", params: {
            user: user_2.username
          }
          expect(response.status).to eq(200)
          expect(moderator_pm.reload.topic_allowed_users.count).to eq(3)
        end
      end

      describe 'when user does not have permission to invite to the topic' do
        fab!(:topic) { pm }

        it "should return the right response" do
          post "/t/#{topic.id}/invite.json", params: {
            user: user.username
          }

          expect(response.status).to eq(403)
        end
      end
    end

    describe "when inviting a group to a topic" do
      fab!(:group) { Fabricate(:group) }

      before do
        sign_in(admin)
      end

      it "should work correctly" do
        email = 'hiro@from.heros'

        post "/t/#{topic.id}/invite.json", params: {
          email: email, group_ids: group.id
        }

        expect(response.status).to eq(200)

        groups = Invite.find_by(email: email).groups
        expect(groups.count).to eq(1)
        expect(groups.first.id).to eq(group.id)
      end
    end
  end

  describe 'invite_group' do
    let!(:admins) { Group[:admins] }

    def invite_group(topic, expected_status)
      post "/t/#{topic.id}/invite-group.json", params: { group: admins.name }
      expect(response.status).to eq(expected_status)
    end

    before do
      admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone])
    end

    describe 'as an anon user' do
      it 'should be forbidden' do
        invite_group(pm, 403)
      end
    end

    describe 'as a normal user' do
      before { sign_in(user) }

      describe 'when user does not have permission to view the topic' do
        it 'should be forbidden' do
          invite_group(pm, 403)
        end
      end

      describe 'when user has permission to view the topic' do
        before do
          pm.allowed_users << user
        end

        it 'should allow user to invite group to topic' do
          invite_group(pm, 200)
          expect(pm.allowed_groups.first.id).to eq(admins.id)
        end
      end
    end

    describe 'as an admin user' do
      before do
        sign_in(admin)
      end

      it "disallows inviting a group to a topic" do
        invite_group(topic, 422)
      end

      it "allows inviting a group to a PM" do
        invite_group(pm, 200)
        expect(pm.allowed_groups.first.id).to eq(admins.id)
      end
    end

    context "when PM has reached maximum allowed numbers of recipients" do
      fab!(:group) { Fabricate(:group, messageable_level: 99) }
      fab!(:pm) { Fabricate(:private_message_topic, user: user) }

      fab!(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

      before do
        SiteSetting.max_allowed_message_recipients = 2
      end

      it "doesn't allow normal users to invite" do
        post "/t/#{pm.id}/invite-group.json", params: {
          group: group.name
        }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t("pm_reached_recipients_limit", recipients_limit: SiteSetting.max_allowed_message_recipients)
        )
      end

      it "allows staff to bypass limits" do
        sign_in(moderator)
        post "/t/#{moderator_pm.id}/invite-group.json", params: {
          group: group.name
        }
        expect(response.status).to eq(200)
        expect(moderator_pm.reload.topic_allowed_users.count + moderator_pm.topic_allowed_groups.count).to eq(3)
      end
    end
  end

  describe 'shared drafts' do
    before do
      SiteSetting.shared_drafts_category = shared_drafts_category.id
    end

    describe "#update_shared_draft" do
      fab!(:other_cat) { Fabricate(:category) }
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }

      context "anonymous" do
        it "doesn't allow staff to update the shared draft" do
          put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
          expect(response.code.to_i).to eq(403)
        end
      end

      context "as a moderator" do
        before do
          sign_in(moderator)
        end

        context "with a shared draft" do
          fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response.status).to eq(200)
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end

        context "without a shared draft" do
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response.status).to eq(200)
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end
      end
    end

    describe "#publish" do
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "fails for anonymous users" do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      it "fails as a regular user" do
        sign_in(user)
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      context "as staff" do
        before do
          sign_in(moderator)
        end

        it "will publish the topic" do
          put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
          expect(response.status).to eq(200)
          json = response.parsed_body['basic_topic']

          result = Topic.find(json['id'])
          expect(result.category_id).to eq(category.id)
          expect(result.visible).to eq(true)
        end

        it 'fails if the destination category is the shared drafts category' do
          put "/t/#{topic.id}/publish.json", params: { destination_category_id: shared_drafts_category.id }
          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe "crawler" do
    context "when not a crawler" do
      it "renders with the application layout" do
        get topic.url

        body = response.body

        expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
        expect(body).to have_tag(:meta, with: { name: 'fragment' })
      end
    end

    context "when a crawler" do
      it "renders with the crawler layout, and handles proper pagination" do
        page1_time = 3.months.ago
        page2_time = 2.months.ago
        page3_time = 1.month.ago

        freeze_time page1_time

        Fabricate(:post, user: post_author2, topic: topic)
        Fabricate(:post, user: post_author3, topic: topic)

        freeze_time page2_time
        Fabricate(:post, user: post_author4, topic: topic)
        Fabricate(:post, user: post_author5, topic: topic)

        freeze_time page3_time
        Fabricate(:post, user: post_author6, topic: topic)

        # ugly, but no interface to set this and we don't want to create
        # 100 posts to test this thing
        TopicView.stubs(:chunk_size).returns(2)

        user_agent = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

        get topic.url, env: { "HTTP_USER_AGENT" => user_agent }

        body = response.body

        expect(body).to have_tag(:body, with: { class: 'crawler' })
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=2")

        expect(response.headers['Last-Modified']).to eq(page1_time.httpdate)

        get topic.url + "?page=2", env: { "HTTP_USER_AGENT" => user_agent }
        body = response.body

        expect(response.headers['Last-Modified']).to eq(page2_time.httpdate)

        expect(body).to include('<link rel="prev" href="' + topic.relative_url)
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=3")

        get topic.url + "?page=3", env: { "HTTP_USER_AGENT" => user_agent }
        body = response.body

        expect(response.headers['Last-Modified']).to eq(page3_time.httpdate)
        expect(body).to include('<link rel="prev" href="' + topic.relative_url + "?page=2")
      end

      context "canonical_url" do
        fab!(:topic_embed) { Fabricate(:topic_embed, embed_url: "https://markvanlan.com") }
        let!(:user_agent) { "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" }

        it "set to topic.url when embed_set_canonical_url is false" do
          get topic_embed.topic.url, env: { "HTTP_USER_AGENT" => user_agent }
          expect(response.body).to include('<link rel="canonical" href="' + topic_embed.topic.url)
        end

        it "set to topic_embed.embed_url when embed_set_canonical_url is true" do
          SiteSetting.embed_set_canonical_url = true
          get topic_embed.topic.url, env: { "HTTP_USER_AGENT" => user_agent }
          expect(response.body).to include('<link rel="canonical" href="' + topic_embed.embed_url)
        end
      end

      context "wayback machine" do
        it "renders crawler layout" do
          get topic.url, env: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36", "HTTP_VIA" => "HTTP/1.0 web.archive.org (Wayback Save Page)" }
          body = response.body

          expect(body).to have_tag(:body, with: { class: 'crawler' })
          expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
        end
      end
    end
  end

  describe "#reset_bump_date" do
    context "errors" do
      it "needs you to be logged in" do
        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)
      end

      [:user].each do |user|
        it "denies access for #{user}" do
          sign_in(Fabricate(user))
          put "/t/#{topic.id}/reset-bump-date.json"
          expect(response.status).to eq(403)
        end
      end

      it "should fail for non-existent topic" do
        max_id = Topic.maximum(:id)
        sign_in(admin)
        put "/t/#{max_id + 1}/reset-bump-date.json"
        expect(response.status).to eq(404)
      end
    end

    [:admin, :moderator, :trust_level_4].each do |user|
      it "should reset bumped_at as #{user}" do
        sign_in(public_send(user))
        topic.update!(bumped_at: 1.hour.ago)
        timestamp = 1.day.ago
        Fabricate(:post, user: post_author1, topic: topic, created_at: timestamp)

        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(timestamp)
      end
    end
  end

  describe '#private_message_reset_new' do
    fab!(:group) do
      Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
        g.add(user_2)
      end
    end

    fab!(:group_message) do
      create_post(
        user: user,
        target_group_names: [group.name],
        archetype: Archetype.private_message
      ).topic
    end

    fab!(:private_message) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    fab!(:private_message_2) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    before do
      sign_in(user_2)
    end

    it 'returns the right response when inbox param is missing' do
      put "/topics/pm-reset-new.json"

      expect(response.status).to eq(400)
    end

    it "returns the right response when trying to reset new private messages of an invalid group" do
      put "/topics/pm-reset-new.json", params: {
        inbox: "group",
        group_name: "randomgroup"
      }

      expect(response.status).to eq(404)
    end

    it "returns the right response when trying to reset new private messages of a restricted group" do
      sign_in(user)

      put "/topics/pm-reset-new.json", params: {
        inbox: "group",
        group_name: group.name
      }

      expect(response.status).to eq(404)
    end

    it "can reset all new group private messages" do
      put "/topics/pm-reset-new.json", params: {
        inbox: "group",
        group_name: group.name
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(group_message.id)

      expect(DismissedTopicUser.count).to eq(1)

      expect(DismissedTopicUser.exists?(topic: group_message, user: user_2))
        .to eq(true)
    end

    it "can reset new personal private messages" do
      put "/topics/pm-reset-new.json", params: {
        inbox: "user",
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(
        private_message.id,
        private_message_2.id
      )

      expect(DismissedTopicUser.count).to eq(2)

      expect(DismissedTopicUser.exists?(user: user_2, topic: [
        private_message,
        private_message_2
      ])).to eq(true)
    end

    it 'can reset new personal and group private messages' do
      stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 1) do
        put "/topics/pm-reset-new.json", params: {
          inbox: "all",
        }

        expect(response.status).to eq(200)

        expect(DismissedTopicUser.count).to eq(3)

        expect(DismissedTopicUser.exists?(user: user_2, topic: [
          private_message,
          private_message_2,
          group_message
        ])).to eq(true)
      end
    end

    it 'returns the right response is topic_ids params is not valid' do
      put "/topics/pm-reset-new.json", params: {
        topic_ids: '1'
      }

      expect(response.status).to eq(400)
    end

    it 'can reset new private messages from given topic ids' do
      put "/topics/pm-reset-new.json", params: {
        topic_ids: [group_message.id, '12345']
      }

      expect(response.status).to eq(200)

      expect(DismissedTopicUser.count).to eq(1)

      expect(DismissedTopicUser.exists?(topic: group_message, user: user_2))
        .to eq(true)

      put "/topics/pm-reset-new.json", params: {
        topic_ids: [private_message.id, '12345']
      }

      expect(response.status).to eq(200)

      expect(DismissedTopicUser.exists?(topic: private_message, user: user_2))
        .to eq(true)
    end
  end

  describe '#archive_message' do
    fab!(:group) do
      Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
        g.add(user)
      end
    end

    fab!(:group_message) do
      create_post(
        user: user,
        target_group_names: [group.name],
        archetype: Archetype.private_message
      ).topic
    end

    it 'should be able to archive a private message' do
      sign_in(user)

      message = MessageBus.track_publish(
        PrivateMessageTopicTrackingState.group_channel(group.id)
      ) do

        put "/t/#{group_message.id}/archive-message.json"

        expect(response.status).to eq(200)
      end.first

      expect(message.data["message_type"]).to eq(
        PrivateMessageTopicTrackingState::GROUP_ARCHIVE_MESSAGE_TYPE
      )

      expect(message.data["payload"]["acting_user_id"]).to eq(user.id)

      body = response.parsed_body

      expect(body["group_name"]).to eq(group.name)
    end
  end
end
