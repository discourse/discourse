require 'rails_helper'

def topics_controller_show_gen_perm_tests(expected, ctx)
  expected.each do |sym, status|
    params = "topic_id: #{sym}.id, slug: #{sym}.slug"
    if sym == :nonexist
      params = "topic_id: nonexist_topic_id"
    end

    method = <<~TEXT
    it 'returns #{status} for #{sym}' do
      get :show, params: { #{params} }
      expect(response.status).to eq(#{status})
    end
    TEXT

    ctx.instance_eval(method)
  end
end

describe TopicsController do

  context 'wordpress' do
    let!(:user) { log_in(:moderator) }
    let(:p1) { Fabricate(:post, user: user) }
    let(:topic) { p1.topic }
    let!(:p2) { Fabricate(:post, topic: topic, user: user) }

    it "returns the JSON in the format our wordpress plugin needs" do
      SiteSetting.external_system_avatars_enabled = false

      get :wordpress, params: { topic_id: topic.id, best: 3 }, format: :json

      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json).to be_present

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

  context 'move_posts' do
    it 'needs you to be logged in' do
      post :move_posts, params: {
        topic_id: 111,
        title: 'blah',
        post_ids: [1, 2, 3]
      }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'moving to a new topic' do
      let(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user, post_number: 1) }
      let(:topic) { p1.topic }

      it "raises an error without post_ids" do
        expect do
          post :move_posts, params: {
            topic_id: topic.id, title: 'blah'
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)

        post :move_posts, params: {
          topic_id: topic.id, title: 'blah', post_ids: [1, 2, 3]
        }, format: :json

        expect(response).to be_forbidden
      end

      it "raises an error when the OP is not a regular post" do
        p2 = Fabricate(:post, topic: topic, post_number: 2, post_type: Post.types[:whisper])
        p3 = Fabricate(:post, topic: topic, post_number: 3)

        post :move_posts, params: {
          topic_id: topic.id, title: 'blah', post_ids: [p2.id, p3.id]
        }, format: :json

        result = ::JSON.parse(response.body)

        expect(result['errors']).to_not be_empty
      end

      context 'success' do
        let(:user) { log_in(:admin) }
        let(:p2) { Fabricate(:post, user: user, topic: topic) }

        it "returns success" do
          p2

          expect do
            post :move_posts, params: {
              topic_id: topic.id,
              title: 'Logan is a good movie',
              post_ids: [p2.id],
              category_id: 123
            }, format: :json
          end.to change { Topic.count }.by(1)

          expect(response).to be_success

          result = ::JSON.parse(response.body)

          expect(result['success']).to eq(true)
          expect(result['url']).to eq(Topic.last.relative_url)
        end

        describe 'when topic has been deleted' do
          it 'should still be able to move posts' do
            PostDestroyer.new(user, topic.first_post).destroy

            expect(topic.reload.deleted_at).to_not be_nil

            expect do
              post :move_posts, params: {
                topic_id: topic.id,
                title: 'Logan is a good movie',
                post_ids: [p2.id],
                category_id: 123
              }, format: :json
            end.to change { Topic.count }.by(1)

            expect(response).to be_success

            result = JSON.parse(response.body)

            expect(result['success']).to eq(true)
            expect(result['url']).to eq(Topic.last.relative_url)
          end
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, topic: topic, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], title: 'blah').returns(nil)

          post :move_posts, params: {
            topic_id: topic.id, title: 'blah', post_ids: [p2.id]
          }, format: :json
        end

        it "returns JSON with a false success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end

    describe "moving replied posts" do
      let!(:user) { log_in(:moderator) }
      let!(:p1) { Fabricate(:post, user: user) }
      let!(:topic) { p1.topic }
      let!(:p2) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: p1.post_number) }

      context 'success' do

        before do
          PostReply.create(post_id: p1.id, reply_id: p2.id)
        end

        it "moves the child posts too" do
          Topic.any_instance.expects(:move_posts).with(user, [p1.id, p2.id], title: 'blah').returns(topic)

          post :move_posts, params: {
            topic_id: topic.id,
            title: 'blah',
            post_ids: [p1.id],
            reply_post_ids: [p1.id]
          }, format: :json
        end
      end

    end

    describe 'moving to an existing topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }
      let(:dest_topic) { Fabricate(:topic) }

      context 'success' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], destination_topic_id: dest_topic.id).returns(topic)

          post :move_posts, params: {
            topic_id: topic.id,
            post_ids: [p2.id],
            destination_topic_id: dest_topic.id
          }, format: :json
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end

      context 'failure' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p2.id], destination_topic_id: dest_topic.id).returns(nil)

          post :move_posts, params: {
            topic_id: topic.id,
            destination_topic_id: dest_topic.id,
            post_ids: [p2.id]
          }, format: :json
        end

        it "returns JSON with a false success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(false)
          expect(result['url']).to be_blank
        end
      end
    end
  end

  context "merge_topic" do
    it 'needs you to be logged in' do
      post :merge_topic, params: {
        topic_id: 111, destination_topic_id: 345
      }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'moving to a new topic' do
      let!(:user) { log_in(:moderator) }
      let(:p1) { Fabricate(:post, user: user) }
      let(:topic) { p1.topic }

      it "raises an error without destination_topic_id" do
        expect do
          post :merge_topic, params: { topic_id: topic.id }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have permission to merge" do
        Guardian.any_instance.expects(:can_move_posts?).returns(false)

        post :merge_topic,
          params: { topic_id: 111, destination_topic_id: 345 },
          format: :json

        expect(response).to be_forbidden
      end

      let(:dest_topic) { Fabricate(:topic) }

      context 'moves all the posts to the destination topic' do
        let(:p2) { Fabricate(:post, user: user) }

        before do
          Topic.any_instance.expects(:move_posts).with(user, [p1.id], destination_topic_id: dest_topic.id).returns(topic)

          post :merge_topic, params: {
            topic_id: topic.id, destination_topic_id: dest_topic.id
          }, format: :json
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end

    end

  end

  context 'change_post_owners' do
    it 'needs you to be logged in' do
      post :change_post_owners, params: {
        topic_id: 111,
        username: 'user_a',
        post_ids: [1, 2, 3]
      }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'forbidden to moderators' do
      let!(:moderator) { log_in(:moderator) }
      it 'correctly denies' do
        post :change_post_owners, params: {
          topic_id: 111, username: 'user_a', post_ids: [1, 2, 3]
        }, format: :json

        expect(response).to be_forbidden
      end
    end

    describe 'forbidden to trust_level_4s' do
      let!(:trust_level_4) { log_in(:trust_level_4) }

      it 'correctly denies' do
        post :change_post_owners, params: {
          topic_id: 111, username: 'user_a', post_ids: [1, 2, 3]
        }, format: :json

        expect(response).to be_forbidden
      end
    end

    describe 'changing ownership' do
      let!(:editor) { log_in(:admin) }
      let(:topic) { Fabricate(:topic) }
      let(:user_a) { Fabricate(:user) }
      let(:p1) { Fabricate(:post, topic_id: topic.id) }
      let(:p2) { Fabricate(:post, topic_id: topic.id) }

      it "raises an error with a parameter missing" do
        expect do
          post :change_post_owners, params: {
            topic_id: 111, post_ids: [1, 2, 3]
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)

        expect do
          post :change_post_owners, params: {
            topic_id: 111, username: 'user_a'
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "calls PostOwnerChanger" do
        PostOwnerChanger.any_instance.expects(:change_owner!).returns(true)
        post :change_post_owners, params: {
          topic_id: topic.id, username: user_a.username_lower, post_ids: [p1.id]
        }, format: :json

        expect(response).to be_success
      end

      it "changes multiple posts" do
        post :change_post_owners, params: {
          topic_id: topic.id, username: user_a.username_lower, post_ids: [p1.id, p2.id]
        }, format: :json

        expect(response).to be_success

        p1.reload
        p2.reload

        expect(p1.user).to_not eq(nil)
        expect(p1.reload.user).to eq(p2.reload.user)
      end

      it "works with deleted users" do
        deleted_user = Fabricate(:user)
        t2 = Fabricate(:topic, user: deleted_user)
        p3 = Fabricate(:post, topic_id: t2.id, user: deleted_user)
        deleted_user.save
        t2.save
        p3.save

        UserDestroyer.new(editor).destroy(deleted_user, delete_posts: true, context: 'test', delete_as_spammer: true)

        post :change_post_owners, params: {
          topic_id: t2.id, username: user_a.username_lower, post_ids: [p3.id]
        }, format: :json

        expect(response).to be_success
        t2.reload
        p3.reload
        expect(t2.deleted_at).to be_nil
        expect(p3.user).to eq(user_a)
      end
    end
  end

  context 'change_timestamps' do
    let(:params) { { topic_id: 1, timestamp: Time.zone.now } }

    it 'needs you to be logged in' do
      put :change_timestamps, params: params, format: :json
      expect(response.status).to eq(403)
    end

    [:moderator, :trust_level_4].each do |user|
      describe "forbidden to #{user}" do
        let!(user) { log_in(user) }

        it 'correctly denies' do
          put :change_timestamps, params: params, format: :json
          expect(response).to be_forbidden
        end
      end
    end

    describe 'changing timestamps' do
      let!(:admin) { log_in(:admin) }
      let(:old_timestamp) { Time.zone.now }
      let(:new_timestamp) { old_timestamp - 1.day }
      let!(:topic) { Fabricate(:topic, created_at: old_timestamp) }
      let!(:p1) { Fabricate(:post, topic_id: topic.id, created_at: old_timestamp) }
      let!(:p2) { Fabricate(:post, topic_id: topic.id, created_at: old_timestamp + 1.day) }

      it 'raises an error with a missing parameter' do
        expect do
          put :change_timestamps, params: { topic_id: 1 }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'should update the timestamps of selected posts' do
        put :change_timestamps, params: {
          topic_id: topic.id, timestamp: new_timestamp.to_f
        }, format: :json

        expect(topic.reload.created_at).to be_within_one_second_of(new_timestamp)
        expect(p1.reload.created_at).to be_within_one_second_of(new_timestamp)
        expect(p2.reload.created_at).to be_within_one_second_of(old_timestamp)
      end
    end
  end

  context 'clear_pin' do
    it 'needs you to be logged in' do
      put :clear_pin, params: { topic_id: 1 }, format: :json
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      let(:topic) { Fabricate(:topic) }
      let!(:user) { log_in }

      it "fails when the user can't see the topic" do
        Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
        put :clear_pin, params: { topic_id: topic.id }, format: :json
        expect(response).not_to be_success
      end

      describe 'when the user can see the topic' do
        it "calls clear_pin_for if the user can see the topic" do
          Topic.any_instance.expects(:clear_pin_for).with(user).once
          put :clear_pin, params: { topic_id: topic.id }, format: :json
        end

        it "succeeds" do
          put :clear_pin, params: { topic_id: topic.id }, format: :json
          expect(response).to be_success
        end
      end

    end

  end

  context 'status' do
    it 'needs you to be logged in' do
      put :status, params: {
        topic_id: 1, status: 'visible', enabled: true
      }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      before do
        @user = log_in(:moderator)
        @topic = Fabricate(:topic, user: @user)
      end

      it "raises an exception if you can't change it" do
        Guardian.any_instance.expects(:can_moderate?).with(@topic).returns(false)

        put :status, params: {
          topic_id: @topic.id, status: 'visible', enabled: 'true'
        }, format: :json

        expect(response).to be_forbidden
      end

      it 'requires the status parameter' do
        expect do
          put :status, params: {
            topic_id: @topic.id, enabled: true
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'requires the enabled parameter' do
        expect do
          put :status, params: {
            topic_id: @topic.id, status: 'visible'
          }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error with a status not in the whitelist' do
        put :status, params: {
          topic_id: @topic.id, status: 'title', enabled: 'true'
        }, format: :json
        expect(response.status).to eq(400)
      end

      it 'should update the status of the topic correctly' do
        @topic = Fabricate(:topic, user: @user, closed: true, topic_timers: [
          Fabricate(:topic_timer, status_type: TopicTimer.types[:open])
        ])

        put :status, params: {
          topic_id: @topic.id, status: 'closed', enabled: 'false'
        }, format: :json

        expect(response).to be_success
        expect(@topic.reload.closed).to eq(false)
        expect(@topic.topic_timers).to eq([])

        body = JSON.parse(response.body)

        expect(body['topic_status_update']).to eq(nil)
      end

    end

  end

  context 'delete_timings' do

    it 'needs you to be logged in' do
      delete :destroy_timings, params: { topic_id: 1 }, format: :json
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      before do
        @user = log_in
        @topic = Fabricate(:topic, user: @user)
        @topic_user = TopicUser.get(@topic, @topic.user)
      end

      it 'deletes the forum topic user record' do
        PostTiming.expects(:destroy_for).with(@user.id, [@topic.id])
        delete :destroy_timings, params: { topic_id: @topic.id }, format: :json
      end

    end

  end

  describe 'mute/unmute' do

    it 'needs you to be logged in' do
      put :mute, params: { topic_id: 99 }, format: :json
      expect(response.status).to eq(403)
    end

    it 'needs you to be logged in' do
      put :unmute, params: { topic_id: 99 }, format: :json
      expect(response.status).to eq(403)
    end
  end

  describe 'recover' do
    it "won't allow us to recover a topic when we're not logged in" do
      put :recover, params: { topic_id: 1 }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: log_in, deleted_at: Time.now, deleted_by: log_in) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(false)
          put :recover, params: { topic_id: topic.id }, format: :json
          expect(response).to be_forbidden
        end
      end

      context 'with permission' do
        before do
          Guardian.any_instance.expects(:can_recover_topic?).with(topic).returns(true)
        end

        it 'succeeds' do
          PostDestroyer.any_instance.expects(:recover)
          put :recover, params: { topic_id: topic.id }, format: :json
          expect(response).to be_success
        end
      end
    end

  end

  describe 'delete' do
    it "won't allow us to delete a topic when we're not logged in" do
      delete :destroy, params: { id: 1 }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      let(:topic) { Fabricate(:topic, user: log_in) }

      describe 'without access' do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          Guardian.any_instance.expects(:can_delete?).with(topic).returns(false)
          delete :destroy, params: { id: topic.id }, format: :json
          expect(response).to be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_delete?).with(topic).returns(true)
        end

        it 'succeeds' do
          PostDestroyer.any_instance.expects(:destroy)
          delete :destroy, params: { id: topic.id }, format: :json
          expect(response).to be_success
        end

      end

    end
  end

  describe 'id_for_slug' do
    let(:topic) { Fabricate(:post).topic }

    it "returns JSON for the slug" do
      get :id_for_slug, params: { slug: topic.slug }, format: :json
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json).to be_present
      expect(json['topic_id']).to eq(topic.id)
      expect(json['url']).to eq(topic.url)
      expect(json['slug']).to eq(topic.slug)
    end

    it "returns invalid access if the user can't see the topic" do
      Guardian.any_instance.expects(:can_see?).with(topic).returns(false)
      get :id_for_slug, params: { slug: topic.slug }, format: :json
      expect(response).not_to be_success
    end
  end

  describe 'show full render' do
    render_views

    it 'correctly renders canoicals' do
      topic = Fabricate(:post).topic
      get :show, params: { topic_id: topic.id, slug: topic.slug }

      expect(response).to be_success
      expect(css_select("link[rel=canonical]").length).to eq(1)
      expect(response.headers["Cache-Control"]).to eq("no-store, must-revalidate, no-cache, private")
    end
  end

  describe 'show unlisted' do
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

      get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json
      expect(response).to be_success

      get :show, params: { topic_id: topic.id, slug: "just-guessing" }, format: :json
      expect(response.code).to eq("301")

      get :show, params: { id: topic.slug }, format: :json
      expect(response.code).to eq("301")
    end
  end

  describe 'show' do

    let(:topic) { Fabricate(:post).topic }
    let!(:p1) { Fabricate(:post, user: topic.user) }
    let!(:p2) { Fabricate(:post, user: topic.user) }

    it 'shows a topic correctly' do
      get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json
      expect(response).to be_success
    end

    it 'return 404 for an invalid page' do
      get :show, params: { topic_id: topic.id, slug: topic.slug, page: 2 }, format: :json
      expect(response.code).to eq("404")
    end

    it 'can find a topic given a slug in the id param' do
      get :show, params: { id: topic.slug }
      expect(response).to redirect_to(topic.relative_url)
    end

    it 'can find a topic when a slug has a number in front' do
      another_topic = Fabricate(:post).topic

      topic.update_column(:slug, "#{another_topic.id}-reasons-discourse-is-awesome")
      get :show, params: { id: "#{another_topic.id}-reasons-discourse-is-awesome" }

      expect(response).to redirect_to(topic.relative_url)
    end

    it 'keeps the post_number parameter around when redirecting' do
      get :show, params: { id: topic.slug, post_number: 42 }
      expect(response).to redirect_to(topic.relative_url + "/42")
    end

    it 'keeps the page around when redirecting' do
      get :show, params: {
        id: topic.slug, post_number: 42, page: 123
      }

      expect(response).to redirect_to(topic.relative_url + "/42?page=123")
    end

    it 'does not accept page params as an array' do
      get :show, params: {
        id: topic.slug, post_number: 42, page: [2]
      }

      expect(response).to redirect_to("#{topic.relative_url}/42?page=1")
    end

    it 'returns 404 when an invalid slug is given and no id' do
      get :show, params: {
        id: 'nope-nope'
      }, format: :json

      expect(response.status).to eq(404)
    end

    it 'returns a 404 when slug and topic id do not match a topic' do
      get :show, params: {
        topic_id: 123123, slug: 'topic-that-is-made-up'
      }, format: :json

      expect(response.status).to eq(404)
    end

    it 'returns a 404 for an ID that is larger than postgres limits' do
      get :show, params: {
        topic_id: 5014217323220164041, slug: 'topic-that-is-made-up'
      }, format: :json

      expect(response.status).to eq(404)
    end

    context 'a topic with nil slug exists' do
      before do
        @nil_slug_topic = Fabricate(:topic)
        Topic.connection.execute("update topics set slug=null where id = #{@nil_slug_topic.id}") # can't find a way to set slug column to null using the model
      end

      it 'returns a 404 when slug and topic id do not match a topic' do
        get :show, params: {
          topic_id: 123123, slug: 'topic-that-is-made-up'
        }, format: :json

        expect(response.status).to eq(404)
      end
    end

    context 'permission errors' do
      let(:allowed_user) { Fabricate(:user) }
      let(:allowed_group) { Fabricate(:group) }
      let(:secure_category) {
        c = Fabricate(:category)
        c.permissions = [[allowed_group, :full]]
        c.save
        allowed_user.groups = [allowed_group]
        allowed_user.save
        c }
      let(:normal_topic) { Fabricate(:topic) }
      let(:secure_topic) { Fabricate(:topic, category: secure_category) }
      let(:private_topic) { Fabricate(:private_message_topic, user: allowed_user) }
      let(:deleted_topic) { Fabricate(:deleted_topic) }
      let(:deleted_secure_topic) { Fabricate(:topic, category: secure_category, deleted_at: 1.day.ago) }
      let(:deleted_private_topic) { Fabricate(:private_message_topic, user: allowed_user, deleted_at: 1.day.ago) }
      let(:nonexist_topic_id) { Topic.last.id + 10000 }

      context 'anonymous' do
        expected = {
          normal_topic: 200,
          secure_topic: 403,
          private_topic: 404,
          deleted_topic: 410,
          deleted_secure_topic: 403,
          deleted_private_topic: 404,
          nonexist: 404
        }
        topics_controller_show_gen_perm_tests(expected, self)
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
        topics_controller_show_gen_perm_tests(expected, self)
      end

      context 'normal user' do
        before do
          log_in(:user)
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
        topics_controller_show_gen_perm_tests(expected, self)
      end

      context 'allowed user' do
        before do
          log_in_user(allowed_user)
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
        topics_controller_show_gen_perm_tests(expected, self)
      end

      context 'moderator' do
        before do
          log_in(:moderator)
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
        topics_controller_show_gen_perm_tests(expected, self)
      end

      context 'admin' do
        before do
          log_in(:admin)
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
        topics_controller_show_gen_perm_tests(expected, self)
      end
    end

    it 'records a view' do
      expect do
        get :show, params: {
          topic_id: topic.id, slug: topic.slug
        }, format: :json
      end.to change(TopicViewItem, :count).by(1)
    end

    it 'records incoming links' do
      user = Fabricate(:user)

      get :show, params: {
        topic_id: topic.id, slug: topic.slug, u: user.username
      }

      expect(IncomingLink.count).to eq(1)
    end

    context 'print' do

      it "doesn't renders the print view when disabled" do
        SiteSetting.max_prints_per_hour_per_user = 0

        get :show, params: {
          topic_id: topic.id, slug: topic.slug, print: true
        }

        expect(response).to be_forbidden
      end

      it 'renders the print view when enabled' do
        SiteSetting.max_prints_per_hour_per_user = 10

        get :show, params: {
          topic_id: topic.id, slug: topic.slug, print: true
        }

        expect(response).to be_successful
      end
    end

    it 'records redirects' do
      request.env['HTTP_REFERER'] = 'http://twitter.com'
      get :show, params: { id: topic.id }

      request.env['HTTP_REFERER'] = nil
      get :show, params: { topic_id: topic.id, slug: topic.slug }

      link = IncomingLink.first
      expect(link.referer).to eq('http://twitter.com')
    end

    it 'tracks a visit for all html requests' do
      current_user = log_in(:coding_horror)
      TopicUser.expects(:track_visit!).with(topic.id, current_user.id)
      get :show, params: { topic_id: topic.id, slug: topic.slug }
    end

    context 'consider for a promotion' do
      let!(:user) { log_in(:coding_horror) }
      let(:promotion) do
        result = double
        Promotion.stubs(:new).with(user).returns(result)
        result
      end

      it "reviews the user for a promotion if they're new" do
        user.update_column(:trust_level, TrustLevel[0])
        Promotion.any_instance.expects(:review)
        get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json
      end
    end

    context 'filters' do

      it 'grabs first page when no filter is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)

        get :show, params: {
          topic_id: topic.id, slug: topic.slug
        }, format: :json
      end

      it 'grabs first page when first page is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(0, 19)

        get :show, params: {
          topic_id: topic.id, slug: topic.slug, page: 1
        }, format: :json
      end

      it 'grabs correct range when a page number is provided' do
        TopicView.any_instance.expects(:filter_posts_in_range).with(20, 39)

        get :show, params: {
          topic_id: topic.id, slug: topic.slug, page: 2
        }, format: :json
      end

      it 'delegates a post_number param to TopicView#filter_posts_near' do
        TopicView.any_instance.expects(:filter_posts_near).with(p2.post_number)

        get :show, params: {
          topic_id: topic.id, slug: topic.slug, post_number: p2.post_number
        }, format: :json
      end
    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.login_required = true }

      context 'and the user is logged in' do
        before { log_in(:coding_horror) }

        it 'shows the topic' do
          get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json
          expect(response).to be_successful
        end
      end

      context 'and the user is not logged in' do
        let(:api_key) { topic.user.generate_api_key(topic.user) }

        it 'redirects to the login page' do
          get :show, params: {
            topic_id: topic.id, slug: topic.slug
          }, format: :json

          expect(response).to redirect_to login_path
        end

        it 'shows the topic if valid api key is provided' do
          get :show, params: {
            topic_id: topic.id, slug: topic.slug, api_key: api_key.key
          }, format: :json

          expect(response).to be_successful
          topic.reload
          # free test, only costs a reload
          expect(topic.views).to eq(1)
        end

        it 'returns 403 for an invalid key' do
          [:json, :html].each do |format|
            get :show, params: {
              topic_id: topic.id, slug: topic.slug, api_key: "bad"
            }, format: format

            expect(response.code.to_i).to be(403)
            expect(response.body).to include(I18n.t("invalid_access"))
          end
        end
      end
    end
  end

  describe '#posts' do
    let(:topic) { Fabricate(:post).topic }

    it 'returns first posts of the topic' do
      get :posts, params: { topic_id: topic.id }, format: :json
      expect(response).to be_success
      expect(response.content_type).to eq('application/json')
    end
  end

  describe '#feed' do
    let(:topic) { Fabricate(:post).topic }

    it 'renders rss of the topic' do
      get :feed, params: { topic_id: topic.id, slug: 'foo' }, format: :rss
      expect(response).to be_success
      expect(response.content_type).to eq('application/rss+xml')
    end
  end

  describe 'update' do
    it "won't allow us to update a topic when we're not logged in" do
      put :update, params: { topic_id: 1, slug: 'xyz' }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'when logged in' do
      before do
        @topic = Fabricate(:topic, user: log_in)
        Fabricate(:post, topic: @topic)
      end

      describe 'without permission' do
        it "raises an exception when the user doesn't have permission to update the topic" do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(false)

          put :update, params: {
            topic_id: @topic.id, slug: @topic.title
          }, format: :json

          expect(response).to be_forbidden
        end
      end

      describe 'with permission' do
        before do
          Guardian.any_instance.expects(:can_edit?).with(@topic).returns(true)
        end

        it 'succeeds' do
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title
          }, format: :json

          expect(response).to be_success
          expect(::JSON.parse(response.body)['basic_topic']).to be_present
        end

        it 'allows a change of title' do
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, title: 'This is a new title for the topic'
          }, format: :json

          @topic.reload
          expect(@topic.title).to eq('This is a new title for the topic')
        end

        it 'triggers a change of category' do
          Topic.any_instance.expects(:change_category_to_id).with(123).returns(true)
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, category_id: 123
          }, format: :json

        end

        it 'allows to change category to "uncategorized"' do
          Topic.any_instance.expects(:change_category_to_id).with(0).returns(true)
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, category_id: ""
          }, format: :json

        end

        it "returns errors with invalid titles" do
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, title: 'asdf'
          }, format: :json

          expect(response).not_to be_success
        end

        it "returns errors when the rate limit is exceeded" do
          EditRateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, title: 'This is a new title for the topic'
          }, format: :json

          expect(response).not_to be_success
        end

        it "returns errors with invalid categories" do
          Topic.any_instance.expects(:change_category_to_id).returns(false)
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, category_id: -1
          }, format: :json

          expect(response).not_to be_success
        end

        it "doesn't call the PostRevisor when there is no changes" do
          PostRevisor.any_instance.expects(:revise!).never
          put :update, params: {
            topic_id: @topic.id, slug: @topic.title, title: @topic.title, category_id: @topic.category_id
          }, format: :json

          expect(response).to be_success
        end

        context 'when topic is private' do
          before do
            @topic.archetype = Archetype.private_message
            @topic.category = nil
            @topic.save!
          end

          context 'when there are no changes' do
            it 'does not call the PostRevisor' do
              PostRevisor.any_instance.expects(:revise!).never
              put :update, params: {
                topic_id: @topic.id, slug: @topic.title, title: @topic.title, category_id: nil
              }, format: :json

              expect(response).to be_success
            end
          end
        end

        context "allow_uncategorized_topics is false" do
          before do
            SiteSetting.allow_uncategorized_topics = false
          end

          it "can add a category to an uncategorized topic" do
            Topic.any_instance.expects(:change_category_to_id).with(456).returns(true)

            put :update, params: {
              topic_id: @topic.id, slug: @topic.title, category_id: 456
            }, format: :json

            expect(response).to be_success
          end
        end

      end
    end
  end

  describe 'invite_group' do
    let :admins do
      Group[:admins]
    end

    let! :admin do
      log_in :admin
    end

    before do
      admins.messageable_level = Group::ALIAS_LEVELS[:everyone]
      admins.save!
    end

    it "disallows inviting a group to a topic" do
      topic = Fabricate(:topic)
      post :invite_group, params: {
        topic_id: topic.id, group: 'admins'
      }, format: :json

      expect(response.status).to eq(422)
    end

    it "allows inviting a group to a PM" do
      topic = Fabricate(:private_message_topic)
      post :invite_group, params: {
        topic_id: topic.id, group: 'admins'
      }, format: :json

      expect(response.status).to eq(200)
      expect(topic.allowed_groups.first.id).to eq(admins.id)
    end
  end

  describe 'make_banner' do

    it 'needs you to be a staff member' do
      log_in
      put :make_banner, params: { topic_id: 99 }, format: :json
      expect(response).to be_forbidden
    end

    describe 'when logged in' do

      it "changes the topic archetype to 'banner'" do
        topic = Fabricate(:topic, user: log_in(:admin))
        Topic.any_instance.expects(:make_banner!)

        put :make_banner, params: { topic_id: topic.id }, format: :json
        expect(response).to be_success
      end
    end
  end

  describe 'remove_allowed_user' do
    it 'admin can be removed from a pm' do

      admin = log_in :admin
      user = Fabricate(:user)
      pm = create_post(user: user, archetype: 'private_message', target_usernames: [user.username, admin.username])

      put :remove_allowed_user, params: {
        topic_id: pm.topic_id, username: admin.username
      }, format: :json

      expect(response.status).to eq(200)
      expect(TopicAllowedUser.where(topic_id: pm.topic_id, user_id: admin.id).first).to eq(nil)
    end
  end

  describe 'remove_banner' do

    it 'needs you to be a staff member' do
      log_in
      put :remove_banner, params: { topic_id: 99 }, format: :json
      expect(response).to be_forbidden
    end

    describe 'when logged in' do

      it "resets the topic archetype" do
        topic = Fabricate(:topic, user: log_in(:admin))
        Topic.any_instance.expects(:remove_banner!)

        put :remove_banner, params: { topic_id: topic.id }, format: :json
        expect(response).to be_success
      end

    end

  end

  describe "bulk" do
    it 'needs you to be logged in' do
      put :bulk, format: :json
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      let!(:user) { log_in }
      let(:operation) { { type: 'change_category', category_id: '1' } }
      let(:topic_ids) { [1, 2, 3] }

      it "requires a list of topic_ids or filter" do
        expect do
          put :bulk, params: { operation: operation }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "requires an operation param" do
        expect do
          put :bulk, params: { topic_ids: topic_ids }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "requires a type field for the operation param" do
        expect do
          put :bulk, params: { topic_ids: topic_ids, operation: {} }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "can find unread" do
        # mark all unread muted
        put :bulk, params: {
          filter: 'unread', operation: { type: :change_notification_level, notification_level_id: 0 }
        }, format: :json

        expect(response.status).to eq(200)
      end

      it "delegates work to `TopicsBulkAction`" do
        topics_bulk_action = mock
        TopicsBulkAction.expects(:new).with(user, topic_ids, operation, group: nil).returns(topics_bulk_action)
        topics_bulk_action.expects(:perform!)

        put :bulk, params: {
          topic_ids: topic_ids, operation: operation
        }, format: :json
      end
    end
  end

  describe 'remove_bookmarks' do
    it "should remove bookmarks properly from non first post" do
      bookmark = PostActionType.types[:bookmark]
      user = log_in

      post = create_post
      post2 = create_post(topic_id: post.topic_id)

      PostAction.act(user, post2, bookmark)

      put :bookmark, params: { topic_id: post.topic_id }, format: :json
      expect(PostAction.where(user_id: user.id, post_action_type: bookmark).count).to eq(2)

      put :remove_bookmarks, params: { topic_id: post.topic_id }, format: :json
      expect(PostAction.where(user_id: user.id, post_action_type: bookmark).count).to eq(0)
    end

    it "should disallow bookmarks on posts you have no access to" do
      log_in
      user = Fabricate(:user)
      pm = create_post(user: user, archetype: 'private_message', target_usernames: [user.username])

      put :bookmark, params: { topic_id: pm.topic_id }, format: :json
      expect(response).to be_forbidden
    end
  end

  describe 'reset_new' do
    it 'needs you to be logged in' do
      put :reset_new, format: :json
      expect(response.status).to eq(403)
    end

    let(:user) { log_in(:user) }

    it "updates the `new_since` date" do
      old_date = 2.years.ago

      user.user_stat.update_column(:new_since, old_date)

      put :reset_new, format: :json
      user.reload
      expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)
    end

  end

  describe "feature_stats" do
    it "works" do
      get :feature_stats, params: { category_id: 1 }, format: :json

      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json["pinned_in_category_count"]).to eq(0)
      expect(json["pinned_globally_count"]).to eq(0)
      expect(json["banner_count"]).to eq(0)
    end

    it "allows unlisted banner topic" do
      Fabricate(:topic, category_id: 1, archetype: Archetype.banner, visible: false)

      get :feature_stats, params: { category_id: 1 }, format: :json
      json = JSON.parse(response.body)
      expect(json["banner_count"]).to eq(1)
    end
  end

  describe "x-robots-tag" do
    it "is included for unlisted topics" do
      topic = Fabricate(:topic, visible: false)
      get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json

      expect(response.headers['X-Robots-Tag']).to eq('noindex')
    end
    it "is not included for normal topics" do
      topic = Fabricate(:topic, visible: true)
      get :show, params: { topic_id: topic.id, slug: topic.slug }, format: :json

      expect(response.headers['X-Robots-Tag']).to eq(nil)
    end
  end

  context "excerpts" do

    it "can correctly get excerpts" do

      first_post = create_post(raw: 'This is the first post :)', title: 'This is a test title I am making yay')
      second_post = create_post(raw: 'This is second post', topic: first_post.topic)

      random_post = Fabricate(:post)

      get :excerpts, params: {
        topic_id: first_post.topic_id,
        post_ids: [first_post.id, second_post.id, random_post.id]
      }, format: :json

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

  context "convert_topic" do
    it 'needs you to be logged in' do
      put :convert_topic, params: { id: 111, type: "private" }, format: :json
      expect(response.status).to eq(403)
    end

    describe 'converting public topic to private message' do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }

      it "raises an error when the user doesn't have permission to convert topic" do
        log_in
        put :convert_topic, params: {
          id: topic.id, type: "private"
        }, format: :json

        expect(response).to be_forbidden
      end

      context "success" do
        before do
          admin = log_in(:admin)
          Topic.any_instance.expects(:convert_to_private_message).with(admin).returns(topic)

          put :convert_topic, params: {
            id: topic.id, type: "private"
          }, format: :json
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end

    describe 'converting private message to public topic' do
      let(:user) { Fabricate(:user) }
      let(:topic) { Fabricate(:topic, user: user) }

      it "raises an error when the user doesn't have permission to convert topic" do
        log_in
        put :convert_topic, params: {
          id: topic.id, type: "public"
        }, format: :json

        expect(response).to be_forbidden
      end

      context "success" do
        before do
          admin = log_in(:admin)
          Topic.any_instance.expects(:convert_to_public_topic).with(admin).returns(topic)

          put :convert_topic, params: {
            id: topic.id, type: "public"
          }, format: :json
        end

        it "returns success" do
          expect(response).to be_success
          result = ::JSON.parse(response.body)
          expect(result['success']).to eq(true)
          expect(result['url']).to be_present
        end
      end
    end
  end

end
