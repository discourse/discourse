require 'rails_helper'

RSpec.describe TopicsController do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }

  describe '#wordpress' do
    let!(:user) { sign_in(Fabricate(:moderator)) }
    let(:p1) { Fabricate(:post, user: user) }
    let(:topic) { p1.topic }
    let!(:p2) { Fabricate(:post, topic: topic, user: user) }

    it "returns the JSON in the format our wordpress plugin needs" do
      SiteSetting.external_system_avatars_enabled = false

      get "/t/#{topic.id}/wordpress.json", params: { best: 3 }

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)

      # The JSON has the data the wordpress plugin needs
      expect(json['id']).to eq(topic.id)
      expect(json['posts_count']).to eq(2)
      expect(json['filtered_posts_count']).to eq(2)

      # Posts
      expect(json['posts'].size).to eq(1)
      post = json['posts'][0]
      expect(post['id']).to eq(p2.id)
      expect(post['username']).to eq(user.username)
      expect(post['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{user.avatar_template}")
      expect(post['name']).to eq(user.name)
      expect(post['created_at']).to be_present
      expect(post['cooked']).to eq(p2.cooked)

      # Participants
      expect(json['participants'].size).to eq(1)
      participant = json['participants'][0]
      expect(participant['id']).to eq(user.id)
      expect(participant['username']).to eq(user.username)
      expect(participant['avatar_template']).to eq("#{Discourse.base_url_no_prefix}#{user.avatar_template}")
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
      let(:user) { Fabricate(:user) }
      let(:moderator) { Fabricate(:moderator) }
      let(:p1) { Fabricate(:post, user: user, post_number: 1) }
      let(:p2) { Fabricate(:post, user: user, post_number: 2, topic: p1.topic) }
      let!(:topic) { p1.topic }

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
        p2 = Fabricate(:post, topic: topic, post_number: 2, post_type: Post.types[:whisper])
        p3 = Fabricate(:post, topic: topic, post_number: 3)

        post "/t/#{topic.id}/move-posts.json", params: {
          title: 'blah', post_ids: [p2.id, p3.id]
        }
        expect(response.status).to eq(422)

        result = ::JSON.parse(response.body)

        expect(result['errors']).to be_present
      end

      context 'success' do
        before { sign_in(Fabricate(:admin)) }

        it "returns success" do
          expect do
            post "/t/#{topic.id}/move-posts.json", params: {
              title: 'Logan is a good movie',
              post_ids: [p2.id],
              category_id: 123,
              tags: ["tag1", "tag2"]
            }
          end.to change { Topic.count }.by(1)

          expect(response.status).to eq(200)

          result = ::JSON.parse(response.body)

          expect(result['success']).to eq(true)
          expect(result['url']).to eq(Topic.last.relative_url)
          expect(Tag.all.pluck(:name)).to contain_exactly("tag1", "tag2")
        end

        describe 'when topic has been deleted' do
          it 'should still be able to move posts' do
            PostDestroyer.new(Fabricate(:admin), topic.first_post).destroy

            expect(topic.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{topic.id}/move-posts.json", params: {
                title: 'Logan is a good movie',
                post_ids: [p2.id],
                category_id: 123
              }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = JSON.parse(response.body)

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
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end

      describe "moving replied posts" do
        context 'success' do
          it "moves the child posts too" do
            user = sign_in(Fabricate(:moderator))
            p1 = Fabricate(:post, topic: topic, user: user)
            p2 = Fabricate(:post, topic: topic, user: user, reply_to_post_number: p1.post_number)
            PostReply.create(post_id: p1.id, reply_id: p2.id)

            post "/t/#{topic.id}/move-posts.json", params: {
              title: 'new topic title',
              post_ids: [p1.id],
              reply_post_ids: [p1.id]
            }
            expect(response.status).to eq(200)

            p1.reload
            p2.reload

            new_topic_id = JSON.parse(response.body)["url"].split("/").last.to_i
            new_topic = Topic.find(new_topic_id)
            expect(p1.topic.id).to eq(new_topic.id)
            expect(p2.topic.id).to eq(new_topic.id)
            expect(p2.reply_to_post_number).to eq(p1.post_number)
          end
        end
      end
    end

    describe 'moving to an existing topic' do
      let!(:user) { sign_in(Fabricate(:moderator)) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }
      let(:dest_topic) { Fabricate(:topic) }
      let(:p2) { Fabricate(:post, user: user, topic: topic) }

      context 'success' do
        it "returns success" do
          user
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p2.id],
            destination_topic_id: dest_topic.id
          }

          expect(response.status).to eq(200)
          result = ::JSON.parse(response.body)
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
        let(:p2) { Fabricate(:post, user: user) }
        it "returns JSON with a false success" do
          post "/t/#{topic.id}/move-posts.json", params: {
            post_ids: [p2.id]
          }

          expect(response.status).to eq(200)
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end

    describe 'moving to a new message' do
      let(:user) { Fabricate(:user) }
      let(:trust_level_4) { Fabricate(:trust_level_4) }
      let(:moderator) { Fabricate(:moderator) }
      let!(:message) { Fabricate(:private_message_topic) }
      let!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: message) }
      let!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: message) }

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
        result = ::JSON.parse(response.body)
        expect(result['errors']).to be_present
      end

      context 'success' do
        before { sign_in(Fabricate(:admin)) }

        it "returns success" do
          SiteSetting.allow_staff_to_tag_pms = true

          expect do
            post "/t/#{message.id}/move-posts.json", params: {
              title: 'Logan is a good movie',
              post_ids: [p2.id],
              archetype: 'private_message',
              tags: ["tag1", "tag2"]
            }
          end.to change { Topic.count }.by(1)

          expect(response.status).to eq(200)

          result = ::JSON.parse(response.body)

          expect(result['success']).to eq(true)
          expect(result['url']).to eq(Topic.last.relative_url)
          expect(Tag.all.pluck(:name)).to contain_exactly("tag1", "tag2")
        end

        describe 'when message has been deleted' do
          it 'should still be able to move posts' do
            PostDestroyer.new(Fabricate(:admin), message.first_post).destroy

            expect(message.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{message.id}/move-posts.json", params: {
                title: 'Logan is a good movie',
                post_ids: [p2.id],
                archetype: 'private_message'
              }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = JSON.parse(response.body)

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
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end

    describe 'moving to an existing message' do
      let!(:user) { sign_in(Fabricate(:admin)) }
      let(:trust_level_4) { Fabricate(:trust_level_4) }
      let(:evil_trout) { Fabricate(:evil_trout) }
      let(:message) { Fabricate(:private_message_topic) }
      let(:p1) { Fabricate(:post, user: user, post_number: 1, topic: message) }
      let(:p2) { Fabricate(:post, user: evil_trout, post_number: 2, topic: message) }

      let(:dest_message) do
        Fabricate(:private_message_topic, user: trust_level_4, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: evil_trout)
        ])
      end

      context 'success' do
        it "returns success" do
          user
          post "/t/#{message.id}/move-posts.json", params: {
            post_ids: [p2.id],
            destination_topic_id: dest_message.id,
            archetype: 'private_message'
          }

          expect(response.status).to eq(200)
          result = ::JSON.parse(response.body)
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
          result = ::JSON.parse(response.body)
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
      let(:moderator) { Fabricate(:moderator) }
      let(:user) { Fabricate(:user) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

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

      let(:dest_topic) { Fabricate(:topic) }

      context 'moves all the posts to the destination topic' do
        it "returns success" do
          sign_in(moderator)
          post "/t/#{topic.id}/merge-topic.json", params: {
            destination_topic_id: dest_topic.id
          }

          expect(response.status).to eq(200)
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end

    describe 'merging into another message' do
      let(:moderator) { Fabricate(:moderator) }
      let(:user) { Fabricate(:user) }
      let(:trust_level_4) { Fabricate(:trust_level_4) }
      let(:message) { Fabricate(:private_message_topic, user: user) }
      let!(:p1) { Fabricate(:post, topic: message, user: trust_level_4) }
      let!(:p2) { Fabricate(:post, topic: message, reply_to_post_number: p1.post_number, user: user) }

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

      let(:dest_message) do
        Fabricate(:private_message_topic, user: trust_level_4, topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: moderator)
        ])
      end

      context 'moves all the posts to the destination message' do
        it "returns success" do
          sign_in(moderator)
          post "/t/#{message.id}/merge-topic.json", params: {
            destination_topic_id: dest_message.id,
            archetype: 'private_message'
          }

          expect(response.status).to eq(200)
          result = ::JSON.parse(response.body)
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

    describe 'forbidden to moderators' do
      before do
        sign_in(Fabricate(:moderator))
      end
      it 'correctly denies' do
        post "/t/111/change-owner.json", params: {
          topic_id: 111, username: 'user_a', post_ids: [1, 2, 3]
        }
        expect(response).to be_forbidden
      end
    end

    describe 'forbidden to trust_level_4s' do
      before do
        sign_in(Fabricate(:trust_level_4))
      end

      it 'correctly denies' do
        post "/t/111/change-owner.json", params: {
          topic_id: 111, username: 'user_a', post_ids: [1, 2, 3]
        }
        expect(response).to be_forbidden
      end
    end

    describe 'changing ownership' do
      let!(:editor) { sign_in(Fabricate(:admin)) }
      let(:topic) { Fabricate(:topic) }
      let(:user_a) { Fabricate(:user) }
      let(:p1) { Fabricate(:post, topic: topic) }
      let(:p2) { Fabricate(:post, topic: topic) }

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
        deleted_user = Fabricate(:user)
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
    end
  end

  describe '#change_timestamps' do
    let(:params) { { timestamp: Time.zone.now } }

    it 'needs you to be logged in' do
      put "/t/1/change-timestamp.json", params: params
      expect(response.status).to eq(403)
    end

    [:moderator, :trust_level_4].each do |user|
      describe "forbidden to #{user}" do
        let!(user) { sign_in(Fabricate(user)) }

        it 'correctly denies' do
          put "/t/1/change-timestamp.json", params: params
          expect(response).to be_forbidden
        end
      end
    end

    describe 'changing timestamps' do
      let!(:admin) { sign_in(Fabricate(:admin)) }
      let(:old_timestamp) { Time.zone.now }
      let(:new_timestamp) { old_timestamp - 1.day }
      let!(:topic) { Fabricate(:topic, created_at: old_timestamp) }
      let!(:p1) { Fabricate(:post, topic: topic, created_at: old_timestamp) }
      let!(:p2) { Fabricate(:post, topic: topic, created_at: old_timestamp + 1.day) }

      it 'should update the timestamps of selected posts' do
        # try to see if we fail with invalid first
        put "/t/1/change-timestamp.json"
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/change-timestamp.json", params: {
          timestamp: new_timestamp.to_f
        }

        expect(response.status).to eq(200)
        expect(topic.reload.created_at).to be_within_one_second_of(new_timestamp)
        expect(p1.reload.created_at).to be_within_one_second_of(new_timestamp)
        expect(p2.reload.created_at).to be_within_one_second_of(old_timestamp)
      end
    end
  end

  describe '#clear_pin' do
    it 'needs you to be logged in' do
      put "/t/1/clear-pin.json"
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      let(:topic) { Fabricate(:topic) }
      let(:pm) { Fabricate(:private_message_topic) }
      let(:user) { Fabricate(:user) }
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

    describe 'when logged in' do
      let(:user) { Fabricate(:user) }
      let(:moderator) { Fabricate(:moderator) }
      let(:topic) { Fabricate(:topic) }
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

      it 'raises an error with a status not in the whitelist' do
        put "/t/#{topic.id}/status.json", params: {
          status: 'title', enabled: 'true'
        }
        expect(response.status).to eq(400)
      end

      it 'should update the status of the topic correctly' do
        topic = Fabricate(:topic, user: user, closed: true)
        Fabricate(:topic_timer, topic: topic, status_type: TopicTimer.types[:open])

        put "/t/#{topic.id}/status.json", params: {
          status: 'closed', enabled: 'false'
        }

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(false)
        expect(topic.topic_timers).to eq([])

        body = JSON.parse(response.body)

        expect(body['topic_status_update']).to eq(nil)
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
        post1 = create_post
        topic = post1.topic

        post2 = create_post(topic_id: topic.id)

        PostTiming.create!(topic: topic, user: user, post_number: 1, msecs: 100)
        PostTiming.create!(topic: topic, user: user, post_number: 2, msecs: 100)

        TopicUser.create!(
          topic: topic,
          user: user,
          last_read_post_number: 2,
          highest_seen_post_number: 2
        )

        sign_in(user)

        delete "/t/#{topic.id}/timings.json?last=1"

        expect(PostTiming.where(topic: topic, user: user, post_number: 2).exists?).to eq(false)
        expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(true)

        expect(TopicUser.where(topic: topic, user: user, last_read_post_number: 1, highest_seen_post_number: 1).exists?).to eq(true)

        PostDestroyer.new(Fabricate(:admin), post2).destroy

        delete "/t/#{topic.id}/timings.json?last=1"

        expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(false)
        expect(TopicUser.where(topic: topic, user: user, last_read_post_number: nil, highest_seen_post_number: nil).exists?).to eq(true)

      end

    end

    context 'when logged in' do
      before do
        @user = sign_in(Fabricate(:user))
        @topic = Fabricate(:topic, user: @user)
        Fabricate(:post, user: @user, topic: @topic, post_number: 2)
        TopicUser.create!(topic: @topic, user: @user)
        PostTiming.create!(topic: @topic, user: @user, post_number: 2, msecs: 1000)
      end

      it 'deletes the forum topic user and post timings records' do
        expect do
          delete "/t/#{@topic.id}/timings.json"
        end.to change { topic_user_post_timings_count(@user, @topic) }.from([1, 1]).to([0, 0])
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
      let(:user) { Fabricate(:user) }
      let(:moderator) { Fabricate(:moderator) }
      let(:topic) { Fabricate(:topic, user: user, deleted_at: Time.now, deleted_by: moderator) }
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
      let(:user) { Fabricate(:user) }
      let(:moderator) { Fabricate(:moderator) }
      let(:topic) { Fabricate(:topic, user: user) }
      let!(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          sign_in(user)
          delete "/t/#{topic.id}.json"
          expect(response).to be_forbidden
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
    let(:topic) { Fabricate(:post).topic }
    let(:pm) { Fabricate(:private_message_topic) }

    it "returns JSON for the slug" do
      get "/t/id_for/#{topic.slug}.json"
      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
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
      let(:topic) { Fabricate(:topic, user: user) }

      before do
        Fabricate(:post, topic: topic)
        SiteSetting.editing_grace_period = 0
        sign_in(user)
      end

      it 'can not change category to a disallowed category' do
        category = Fabricate(:category)
        category.set_permissions(staff: :full)
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      it 'can not move to a category that requires topic approval' do
        category = Fabricate(:category)
        category.custom_fields[Category::REQUIRE_TOPIC_APPROVAL] = true
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          topic.update!(archived: true)
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(403)
        end
      end

      describe 'with permission' do
        it 'succeeds' do
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(200)
          expect(::JSON.parse(response.body)['basic_topic']).to be_present
        end

        it "can update a topic to an uncategorized topic" do
          topic.update!(category: Fabricate(:category))

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
        end

        it "returns errors with invalid titles" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: {
            title: 'asdf'
          }

          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)['errors']).to be_present
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

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.allow_uncategorized_topics = false
          end

          it "can add a category to an uncategorized topic" do
            category = Fabricate(:category)

            put "/t/#{topic.slug}/#{topic.id}.json", params: {
              category_id: category.id
            }

            expect(response.status).to eq(200)
            expect(topic.reload.category).to eq(category)
          end
        end
      end
    end
  end

  describe '#show' do
    let(:private_topic) { Fabricate(:private_message_topic) }
    let(:topic) { Fabricate(:post).topic }

    let!(:p1) { Fabricate(:post, user: topic.user) }
    let!(:p2) { Fabricate(:post, user: topic.user) }

    describe 'when topic is not allowed' do
      it 'should return the right response' do
        sign_in(user)

        get "/t/#{private_topic.id}.json"

        expect(response.status).to eq(403)
        expect(response.body).to eq(I18n.t('invalid_access'))
      end
    end

    it 'correctly renders canoicals' do
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
      topic = Fabricate(:topic, visible: false)
      Fabricate(:post, topic: topic)

      get "/t/#{topic.id}.json", params: { slug: topic.slug }
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
      another_topic = Fabricate(:post).topic

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
      let(:allowed_user) { Fabricate(:user) }
      let(:allowed_group) { Fabricate(:group) }
      let(:secure_category) do
        c = Fabricate(:category)
        c.permissions = [[allowed_group, :full]]
        c.save
        allowed_user.groups = [allowed_group]
        allowed_user.save
        c
      end
      let(:normal_topic) { Fabricate(:topic) }
      let(:secure_topic) { Fabricate(:topic, category: secure_category) }
      let(:private_topic) { Fabricate(:private_message_topic, user: allowed_user) }
      let(:deleted_topic) { Fabricate(:deleted_topic) }
      let(:deleted_secure_topic) { Fabricate(:topic, category: secure_category, deleted_at: 1.day.ago) }
      let(:deleted_private_topic) { Fabricate(:private_message_topic, user: allowed_user, deleted_at: 1.day.ago) }
      let(:nonexist_topic_id) { Topic.last.id + 10000 }

      shared_examples "various scenarios" do |expected|
        expected.each do |key, value|
          it "returns #{value} for #{key}" do
            slug = key == :nonexist ? "garbage-slug" : eval(key.to_s).slug
            topic_id = key == :nonexist ? nonexist_topic_id : eval(key.to_s).id
            get "/t/#{slug}/#{topic_id}.json"
            expect(response.status).to eq(value)
          end
        end
      end

      context 'anonymous' do
        expected = {
          normal_topic: 200,
          secure_topic: 403,
          private_topic: 403,
          deleted_topic: 410,
          deleted_secure_topic: 403,
          deleted_private_topic: 403,
          nonexist: 404
        }
        include_examples "various scenarios", expected
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
          nonexist: 302
        }
        include_examples "various scenarios", expected
      end

      context 'normal user' do
        before do
          sign_in(Fabricate(:user))
        end

        expected = {
          normal_topic: 200,
          secure_topic: 403,
          private_topic: 403,
          deleted_topic: 410,
          deleted_secure_topic: 403,
          deleted_private_topic: 403,
          nonexist: 404
        }
        include_examples "various scenarios", expected
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
          nonexist: 404
        }
        include_examples "various scenarios", expected
      end

      context 'moderator' do
        before do
          sign_in(Fabricate(:moderator))
        end

        expected = {
          normal_topic: 200,
          secure_topic: 403,
          private_topic: 403,
          deleted_topic: 200,
          deleted_secure_topic: 403,
          deleted_private_topic: 403,
          nonexist: 404
        }
        include_examples "various scenarios", expected
      end

      context 'admin' do
        before do
          sign_in(Fabricate(:admin))
        end

        expected = {
          normal_topic: 200,
          secure_topic: 200,
          private_topic: 200,
          deleted_topic: 200,
          deleted_secure_topic: 200,
          deleted_private_topic: 200,
          nonexist: 404
        }
        include_examples "various scenarios", expected
      end
    end

    it 'records a view' do
      expect do
        get "/t/#{topic.slug}/#{topic.id}.json"
      end.to change(TopicViewItem, :count).by(1)
    end

    it 'records a view to invalid post_number' do
      user = Fabricate(:user)

      expect do
        get "/t/#{topic.slug}/#{topic.id}/#{256**4}", params: {
          u: user.username
        }
        expect(response.status).to eq(200)
      end.to change { IncomingLink.count }.by(1)

    end

    it 'records incoming links' do
      user = Fabricate(:user)

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
      expect(topic_user.last_visited_at).to eq(topic_user.first_visited_at)
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
        json = JSON.parse(response.body)
        json["post_stream"]["posts"].map { |post| post["id"] }
      end

      before do
        TopicView.stubs(:chunk_size).returns(2)
        @post_ids = topic.posts.pluck(:id)
        3.times do
          @post_ids << Fabricate(:post, topic: topic).id
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
      end
    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.login_required = true }

      context 'and the user is logged in' do
        before { sign_in(Fabricate(:coding_horror)) }

        it 'shows the topic' do
          get "/t/#{topic.slug}/#{topic.id}.json"
          expect(response.status).to eq(200)
        end
      end

      context 'and the user is not logged in' do
        let(:api_key) { topic.user.generate_api_key(topic.user) }

        it 'redirects to the login page' do
          get "/t/#{topic.slug}/#{topic.id}.json"

          expect(response).to redirect_to login_path
        end

        it 'shows the topic if valid api key is provided' do
          get "/t/#{topic.slug}/#{topic.id}.json", params: { api_key: api_key.key }

          expect(response.status).to eq(200)
          topic.reload
          expect(topic.views).to eq(1)
        end

        it 'returns 403 for an invalid key' do
          [:json, :html].each do |format|
            get "/t/#{topic.slug}/#{topic.id}.#{format}", params: { api_key: "bad" }

            expect(response.code.to_i).to be(403)
            expect(response.body).to include(I18n.t("invalid_access"))
          end
        end
      end
    end

    it "is included for unlisted topics" do
      topic = Fabricate(:topic, visible: false)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
    end

    it "is not included for normal topics" do
      topic = Fabricate(:topic, visible: true)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.headers['X-Robots-Tag']).to eq(nil)
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
        Discourse.stubs(:base_uri).returns("/eviltrout")
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

    describe "set_locale" do
      def headers(locale)
        { HTTP_ACCEPT_LANGUAGE: locale }
      end

      context "allow_user_locale disabled" do
        context "accept-language header differs from default locale" do
          before do
            SiteSetting.allow_user_locale = false
            SiteSetting.default_locale = "en"
          end

          context "with an anonymous user" do
            it "uses the default locale" do
              get "/t/#{topic.id}.json", headers: headers("fr")

              expect(response.status).to eq(200)
              expect(I18n.locale).to eq(:en)
            end
          end

          context "with a logged in user" do
            it "it uses the default locale" do
              user = Fabricate(:user, locale: :fr)
              sign_in(user)

              get "/t/#{topic.id}.json", headers: headers("fr")

              expect(response.status).to eq(200)
              expect(I18n.locale).to eq(:en)
            end
          end
        end
      end

      context "set_locale_from_accept_language_header enabled" do
        context "accept-language header differs from default locale" do
          before do
            SiteSetting.allow_user_locale = true
            SiteSetting.set_locale_from_accept_language_header = true
            SiteSetting.default_locale = "en"
          end

          context "with an anonymous user" do
            it "uses the locale from the headers" do
              get "/t/#{topic.id}.json", headers: headers("fr")
              expect(response.status).to eq(200)
              expect(I18n.locale).to eq(:fr)
            end
          end

          context "with a logged in user" do
            it "uses the user's preferred locale" do
              user = Fabricate(:user, locale: :fr)
              sign_in(user)

              get "/t/#{topic.id}.json", headers: headers("fr")
              expect(response.status).to eq(200)
              expect(I18n.locale).to eq(:fr)
            end
          end
        end

        context "the preferred locale includes a region" do
          it "returns the locale and region separated by an underscore" do
            SiteSetting.allow_user_locale = true
            SiteSetting.set_locale_from_accept_language_header = true
            SiteSetting.default_locale = "en"

            get "/t/#{topic.id}.json", headers: headers("zh-CN")
            expect(response.status).to eq(200)
            expect(I18n.locale).to eq(:zh_CN)
          end
        end

        context 'accept-language header is not set' do
          it 'uses the site default locale' do
            SiteSetting.allow_user_locale = true
            SiteSetting.default_locale = 'en'

            get "/t/#{topic.id}.json", headers: headers("")
            expect(response.status).to eq(200)
            expect(I18n.locale).to eq(:en)
          end
        end
      end
    end

    describe "read only header" do
      it "returns no read only header by default" do
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.headers['Discourse-Readonly']).to eq(nil)
      end

      it "returns a readonly header if the site is read only" do
        Discourse.received_readonly!
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.headers['Discourse-Readonly']).to eq('true')
      end
    end

    describe "image only topic" do
      it "uses image alt tag for meta description" do
        post = Fabricate(:post, raw: "![image_description|690x405](upload://sdtr5O5xaxf0iEOxICxL36YRj86.png)")

        get post.topic.url

        body = response.body
        expect(body).to have_tag(:meta, with: { name: 'description', content: '[image_description]' })
      end
    end
  end

  describe '#post_ids' do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    before do
      TopicView.stubs(:chunk_size).returns(1)
    end

    it 'returns the right post ids' do
      post2 = Fabricate(:post, topic: topic)
      post3 = Fabricate(:post, topic: topic)

      get "/t/#{topic.id}/post_ids.json", params: {
        post_number: post.post_number
      }

      expect(response.status).to eq(200)

      body = JSON.parse(response.body)

      expect(body["post_ids"]).to eq([post2.id, post3.id])
    end

    describe 'filtering by post number with filters' do
      describe 'username filters' do
        let(:user) { Fabricate(:user) }
        let(:post) { Fabricate(:post, user: user) }
        let!(:post2) { Fabricate(:post, topic: topic, user: user) }
        let!(:post3) { Fabricate(:post, topic: topic) }

        it 'should return the right posts' do
          get "/t/#{topic.id}/post_ids.json", params: {
            post_number: post.post_number,
            username_filters: post2.user.username
          }

          expect(response.status).to eq(200)

          body = JSON.parse(response.body)

          expect(body["post_ids"]).to eq([post2.id])
        end
      end

      describe 'summary filter' do
        let!(:post2) { Fabricate(:post, topic: topic, percent_rank: 0.2) }
        let!(:post3) { Fabricate(:post, topic: topic) }

        it 'should return the right posts' do
          get "/t/#{topic.id}/post_ids.json", params: {
            post_number: post.post_number,
            filter: 'summary'
          }

          expect(response.status).to eq(200)

          body = JSON.parse(response.body)

          expect(body["post_ids"]).to eq([post2.id])
        end
      end
    end
  end

  describe '#posts' do
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    it 'returns first post of the topic' do
      get "/t/#{topic.id}/posts.json"

      expect(response.status).to eq(200)

      body = JSON.parse(response.body)

      expect(body["post_stream"]["posts"].first["id"]).to eq(post.id)
    end

    describe 'filtering by post number with filters' do
      describe 'username filters' do
        let!(:post2) { Fabricate(:post, topic: topic, user: Fabricate(:user)) }
        let!(:post3) { Fabricate(:post, topic: topic) }

        it 'should return the right posts' do
          TopicView.stubs(:chunk_size).returns(2)

          get "/t/#{topic.id}/posts.json", params: {
            post_number: post.post_number,
            username_filters: post2.user.username,
            asc: true
          }

          expect(response.status).to eq(200)

          body = JSON.parse(response.body)

          expect(body["post_stream"]["posts"].first["id"]).to eq(post2.id)
        end
      end

      describe 'summary filter' do
        let!(:post2) { Fabricate(:post, topic: topic, percent_rank: 0.2) }
        let!(:post3) { Fabricate(:post, topic: topic) }

        it 'should return the right posts' do
          TopicView.stubs(:chunk_size).returns(2)

          get "/t/#{topic.id}/posts.json", params: {
            post_number: post.post_number,
            filter: 'summary',
            asc: true
          }

          expect(response.status).to eq(200)

          body = JSON.parse(response.body)

          expect(body["post_stream"]["posts"].first["id"]).to eq(post2.id)
        end
      end
    end
  end

  describe '#feed' do
    let(:topic) { Fabricate(:post).topic }

    it 'renders rss of the topic' do
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('application/rss+xml')
    end

    it 'renders rss of the topic correctly with subfolder' do
      GlobalSetting.stubs(:relative_url_root).returns('/forum')
      Discourse.stubs(:base_uri).returns("/forum")
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("/forum/forum")
      expect(response.body).to include("http://test.localhost/forum/t/#{topic.slug}")
    end
  end

  describe '#invite_group' do
    let(:admins) { Group[:admins] }

    let!(:admin) { sign_in(Fabricate(:admin)) }

    before do
      admins.messageable_level = Group::ALIAS_LEVELS[:everyone]
      admins.save!
    end

    it "disallows inviting a group to a topic" do
      topic = Fabricate(:topic)
      post "/t/#{topic.id}/invite-group.json", params: {
        group: 'admins'
      }

      expect(response.status).to eq(422)
    end

    it "allows inviting a group to a PM" do
      topic = Fabricate(:private_message_topic)
      post "/t/#{topic.id}/invite-group.json", params: {
        group: 'admins'
      }

      expect(response.status).to eq(200)
      expect(topic.allowed_groups.first.id).to eq(admins.id)
    end
  end

  describe '#make_banner' do
    it 'needs you to be a staff member' do
      sign_in(Fabricate(:user))
      put "/t/99/make-banner.json"
      expect(response).to be_forbidden
    end

    describe 'when logged in' do
      it "changes the topic archetype to 'banner'" do
        topic = Fabricate(:topic, user: sign_in(Fabricate(:admin)))

        put "/t/#{topic.id}/make-banner.json"
        expect(response.status).to eq(200)
        topic.reload
        expect(topic.archetype).to eq(Archetype.banner)
      end
    end
  end

  describe '#remove_banner' do
    it 'needs you to be a staff member' do
      sign_in(Fabricate(:user))
      put "/t/99/remove-banner.json"
      expect(response).to be_forbidden
    end

    describe 'when logged in' do
      it "resets the topic archetype" do
        topic = Fabricate(:topic, user: sign_in(Fabricate(:admin)), archetype: Archetype.banner)

        put "/t/#{topic.id}/remove-banner.json"
        expect(response.status).to eq(200)
        topic.reload
        expect(topic.archetype).to eq(Archetype.default)
      end
    end
  end

  describe '#remove_allowed_user' do
    it 'admin can be removed from a pm' do
      admin = sign_in(Fabricate(:admin))
      user = Fabricate(:user)
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
      let!(:user) { sign_in(Fabricate(:user)) }
      let(:operation) { { type: 'change_category', category_id: '1' } }
      let(:topic_ids) { [1, 2, 3] }

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
    end
  end

  describe '#remove_bookmarks' do
    it "should remove bookmarks properly from non first post" do
      bookmark = PostActionType.types[:bookmark]
      user = sign_in(Fabricate(:user))

      post = create_post
      post2 = create_post(topic_id: post.topic_id)

      PostAction.act(user, post2, bookmark)

      put "/t/#{post.topic_id}/bookmark.json"
      expect(PostAction.where(user_id: user.id, post_action_type: bookmark).count).to eq(2)

      put "/t/#{post.topic_id}/remove_bookmarks.json"
      expect(PostAction.where(user_id: user.id, post_action_type: bookmark).count).to eq(0)
    end

    it "should disallow bookmarks on posts you have no access to" do
      sign_in(Fabricate(:user))
      user = Fabricate(:user)
      pm = create_post(user: user, archetype: 'private_message', target_usernames: [user.username])

      put "/t/#{pm.topic_id}/bookmark.json"
      expect(response).to be_forbidden
    end
  end

  describe '#reset_new' do
    let(:user) { sign_in(Fabricate(:user)) }
    it 'needs you to be logged in' do
      put "/topics/reset-new.json"
      expect(response.status).to eq(403)
    end

    it "updates the `new_since` date" do
      old_date = 2.years.ago

      user.user_stat.update_column(:new_since, old_date)

      put "/topics/reset-new.json"
      expect(response.status).to eq(200)
      user.reload
      expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)
    end
  end

  describe '#feature_stats' do
    it "works" do
      get "/topics/feature_stats.json", params: { category_id: 1 }

      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["pinned_in_category_count"]).to eq(0)
      expect(json["pinned_globally_count"]).to eq(0)
      expect(json["banner_count"]).to eq(0)
    end

    it "allows unlisted banner topic" do
      Fabricate(:topic, category_id: 1, archetype: Archetype.banner, visible: false)

      get "/topics/feature_stats.json", params: { category_id: 1 }
      json = JSON.parse(response.body)
      expect(json["banner_count"]).to eq(1)
    end
  end

  describe '#excerpts' do
    it "can correctly get excerpts" do
      first_post = create_post(raw: 'This is the first post :)', title: 'This is a test title I am making yay')
      second_post = create_post(raw: 'This is second post', topic: first_post.topic)

      random_post = Fabricate(:post)

      get "/t/#{first_post.topic_id}/excerpts.json", params: {
        post_ids: [first_post.id, second_post.id, random_post.id]
      }

      json = JSON.parse(response.body)
      json.sort! { |a, b| a["post_id"] <=> b["post_id"] }

      # no random post
      expect(json.length).to eq(2)
      # keep emoji images
      expect(json[0]["excerpt"]).to match(/emoji/)
      expect(json[0]["excerpt"]).to match(/first post/)
      expect(json[0]["username"]).to eq(first_post.user.username)
      expect(json[0]["post_id"]).to eq(first_post.id)

      expect(json[1]["excerpt"]).to match(/second post/)
    end
  end

  describe '#convert_topic' do
    it 'needs you to be logged in' do
      put "/t/111/convert-topic/private.json"
      expect(response.status).to eq(403)
    end

    describe 'converting public topic to private message' do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(Fabricate(:user))
        put "/t/#{topic.id}/convert-topic/private.json"
        expect(response).to be_forbidden
      end

      context "success" do
        it "returns success" do
          sign_in(Fabricate(:admin))
          put "/t/#{topic.id}/convert-topic/private.json"

          topic.reload
          expect(topic.archetype).to eq(Archetype.private_message)
          expect(response.status).to eq(200)

          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end

    describe 'converting private message to public topic' do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:private_message_topic, user: user) }

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(Fabricate(:user))
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden
      end

      context "success" do
        it "returns success" do
          sign_in(Fabricate(:admin))
          put "/t/#{topic.id}/convert-topic/public.json"

          topic.reload
          expect(topic.archetype).to eq(Archetype.default)
          expect(response.status).to eq(200)

          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end
  end

  describe '#timings' do
    let(:post_1) { Fabricate(:post, topic: topic) }

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
        expect(JSON.parse(response.body)["error_type"]).to eq('invalid_access')
      end
    end

    context 'when logged in as an admin' do
      let(:admin) { Fabricate(:admin) }

      before do
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

        expect(topic_status_update.execute_at)
          .to be_within(1.second).of(24.hours.from_now)

        json = JSON.parse(response.body)

        expect(DateTime.parse(json['execute_at']))
          .to be_within(1.seconds).of(DateTime.parse(topic_status_update.execute_at.to_s))

        expect(json['duration']).to eq(topic_status_update.duration)
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

        json = JSON.parse(response.body)

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

          expect(topic_status_update.execute_at)
            .to be_within(1.second).of(24.hours.from_now)

          expect(topic_status_update.status_type)
            .to eq(TopicTimer.types[:publish_to_category])

          json = JSON.parse(response.body)

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
        let(:topic) { Fabricate(:topic, user: user) }

        it 'should return the right response' do
          user.update!(trust_level: TrustLevel[2])

          expect do
            post "/t/#{topic.id}/invite.json", params: {
              email: 'someguy@email.com'
            }
          end.to change { Invite.where(invited_by_id: user.id).count }.by(1)

          expect(response.status).to eq(200)
        end
      end

      describe 'when user is a group manager' do
        let(:group) { Fabricate(:group).tap { |g| g.add_owner(user) } }
        let(:private_category)  { Fabricate(:private_category, group: group) }

        let(:group_private_topic) do
          Fabricate(:topic, category: private_category, user: user)
        end

        let(:recipient) { 'jake@adventuretime.ooo' }

        it "should attach group to the invite" do
          post "/t/#{group_private_topic.id}/invite.json", params: {
            user: recipient,
            group_ids: "#{group.id},123"
          }

          expect(response.status).to eq(200)
          expect(Invite.find_by(email: recipient).groups).to eq([group])
        end

        describe 'when group is available to automatic groups only' do
          before do
            group.update!(automatic: true)
          end

          it 'should return the right response' do
            post "/t/#{group_private_topic.id}/invite.json", params: {
              user: Fabricate(:user)
            }

            expect(response.status).to eq(403)
          end
        end

        describe 'when user is not part of the required group' do
          it 'should return the right response' do
            post "/t/#{group_private_topic.id}/invite.json", params: {
              user: Fabricate(:user)
            }

            expect(response.status).to eq(422)

            response_body = JSON.parse(response.body)

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
          post "/t/999/invite.json", params: {
            email: Fabricate(:user).email
          }

          expect(response.status).to eq(400)
        end
      end

      it 'requires an email parameter' do
        post "/t/#{topic.id}/invite.json"
        expect(response.status).to eq(400)
      end

      describe "when PM has reached maximum allowed numbers of recipients" do
        let(:user2) { Fabricate(:user) }
        let(:pm) { Fabricate(:private_message_topic, user: user) }

        let(:moderator) { Fabricate(:moderator) }
        let(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

        before do
          SiteSetting.max_allowed_message_recipients = 2
        end

        it "doesn't allow normal users to invite" do
          post "/t/#{pm.id}/invite.json", params: {
            user: user2.username
          }
          expect(response.status).to eq(422)
          expect(JSON.parse(response.body)["errors"]).to contain_exactly(
            I18n.t("pm_reached_recipients_limit", recipients_limit: SiteSetting.max_allowed_message_recipients)
          )
        end

        it "allows staff to bypass limits" do
          sign_in(moderator)
          post "/t/#{moderator_pm.id}/invite.json", params: {
            user: user2.username
          }
          expect(response.status).to eq(200)
          expect(moderator_pm.reload.topic_allowed_users.count).to eq(3)
        end
      end

      describe 'when user does not have permission to invite to the topic' do
        let(:topic) { Fabricate(:private_message_topic) }

        it "should return the right response" do
          post "/t/#{topic.id}/invite.json", params: {
            user: user.username
          }

          expect(response.status).to eq(403)
        end
      end
    end

    describe "when inviting a group to a topic" do
      let(:group) { Fabricate(:group) }

      before do
        sign_in(Fabricate(:admin))
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
    let(:admins) { Group[:admins] }
    let(:pm) { Fabricate(:private_message_topic) }

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
      let!(:user) { sign_in(Fabricate(:user)) }

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
      let!(:admin) { sign_in(Fabricate(:admin)) }

      it "disallows inviting a group to a topic" do
        topic = Fabricate(:topic)
        invite_group(topic, 422)
      end

      it "allows inviting a group to a PM" do
        invite_group(pm, 200)
        expect(pm.allowed_groups.first.id).to eq(admins.id)
      end
    end

    context "when PM has reached maximum allowed numbers of recipients" do
      let(:group) { Fabricate(:group, messageable_level: 99) }
      let(:pm) { Fabricate(:private_message_topic, user: user) }

      let(:moderator) { Fabricate(:moderator) }
      let(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

      before do
        SiteSetting.max_allowed_message_recipients = 2
      end

      it "doesn't allow normal users to invite" do
        post "/t/#{pm.id}/invite-group.json", params: {
          group: group.name
        }
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)["errors"]).to contain_exactly(
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
    let(:shared_drafts_category) { Fabricate(:category) }
    let(:category) { Fabricate(:category) }

    before do
      SiteSetting.shared_drafts_category = shared_drafts_category.id
    end

    describe "#update_shared_draft" do
      let(:other_cat) { Fabricate(:category) }
      let(:category) { Fabricate(:category) }
      let(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }

      context "anonymous" do
        it "doesn't allow staff to update the shared draft" do
          put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
          expect(response.code.to_i).to eq(403)
        end
      end

      context "as a moderator" do
        let(:moderator) { Fabricate(:moderator) }
        before do
          sign_in(moderator)
        end

        context "with a shared draft" do
          let!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
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
      let(:category) { Fabricate(:category) }
      let(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      let(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
      let(:moderator) { Fabricate(:moderator) }

      it "fails for anonymous users" do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      it "fails as a regular user" do
        sign_in(Fabricate(:user))
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
          json = ::JSON.parse(response.body)['basic_topic']

          result = Topic.find(json['id'])
          expect(result.category_id).to eq(category.id)
          expect(result.visible).to eq(true)
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

        topic = Fabricate(:topic)
        Fabricate(:post, topic: topic)
        Fabricate(:post, topic: topic)

        freeze_time page2_time
        Fabricate(:post, topic: topic)
        Fabricate(:post, topic: topic)

        freeze_time page3_time
        Fabricate(:post, topic: topic)

        # ugly, but no inteface to set this and we don't want to create
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
    end

  end

  describe "#reset_bump_date" do
    context "errors" do
      let(:topic) { Fabricate(:topic) }

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

      it "should fail for non-existend topic" do
        sign_in(Fabricate(:admin))
        put "/t/1/reset-bump-date.json"
        expect(response.status).to eq(404)
      end
    end

    [:admin, :moderator, :trust_level_4].each do |user|
      it "should reset bumped_at as #{user}" do
        sign_in(Fabricate(user))
        topic = Fabricate(:topic, bumped_at: 1.hour.ago)
        timestamp = 1.day.ago
        Fabricate(:post, topic: topic, created_at: timestamp)

        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to be_within_one_second_of(timestamp)
      end
    end
  end
end
