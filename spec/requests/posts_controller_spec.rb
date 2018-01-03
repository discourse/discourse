require 'rails_helper'

RSpec.describe PostsController do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic) }
  let(:public_post) { Fabricate(:post, user: user, topic: topic) }

  let(:private_topic) do
    Fabricate(:topic, archetype: Archetype.private_message, category: nil)
  end

  let(:private_post) { Fabricate(:post, user: user, topic: private_topic) }

  describe '#create' do
    before do
      sign_in(user)
    end

    it 'creates the post' do
      post "/posts.json", params: {
        raw: 'this is the test content',
        title: 'this is the test title for the topic',
        category: category.id,
        meta_data: { xyz: 'abc' }
      }

      expect(response).to be_success

      new_post = Post.last
      topic = new_post.topic

      expect(new_post.user).to eq(user)
      expect(new_post.raw).to eq('this is the test content')
      expect(topic.title).to eq('This is the test title for the topic')
      expect(topic.category).to eq(category)
      expect(topic.meta_data).to eq("xyz" => 'abc')
    end

    it 'can create a reply to a post' do
      SiteSetting.queue_jobs = true

      topic = Fabricate(:private_message_post, user: user).topic
      post_2 = Fabricate(:private_message_post, user: user, topic: topic)

      post "/posts.json", params: {
        raw: 'this is the test content',
        topic_id: topic.id,
        reply_to_post_number: post_2.post_number,
        image_sizes: { width: '100', height: '200' }
      }

      expect(response).to be_success

      new_post = Post.last
      topic = new_post.topic

      expect(new_post.user).to eq(user)
      expect(new_post.raw).to eq('this is the test content')
      expect(new_post.reply_to_post_number).to eq(post_2.post_number)

      job_args = Jobs::ProcessPost.jobs.first["args"].first

      expect(job_args["image_sizes"]).to eq("width" => '100', "height" => '200')
    end

    it 'creates a private post' do
      user_2 = Fabricate(:user)
      user_3 = Fabricate(:user)

      post "/posts.json", params: {
        raw: 'this is the test content',
        archetype: 'private_message',
        title: "this is some post",
        target_usernames: "#{user_2.username},#{user_3.username}"
      }

      expect(response).to be_success

      new_post = Post.last
      new_topic = Topic.last

      expect(new_post.user).to eq(user)
      expect(new_topic.private_message?).to eq(true)
      expect(new_topic.allowed_users).to contain_exactly(user, user_2, user_3)
    end

    describe 'warnings' do
      let(:user_2) { Fabricate(:user) }

      context 'as a staff user' do
        before do
          sign_in(Fabricate(:admin))
        end

        it 'should be able to mark a topic as warning' do
          post "/posts.json", params: {
            raw: 'this is the test content',
            archetype: 'private_message',
            title: "this is some post",
            target_usernames: user_2.username,
            is_warning: true
          }

          expect(response).to be_success

          new_topic = Topic.last

          expect(new_topic.title).to eq('This is some post')
          expect(new_topic.is_official_warning?).to eq(true)
        end

        it 'should be able to mark a topic as not a warning' do
          post "/posts.json", params: {
            raw: 'this is the test content',
            archetype: 'private_message',
            title: "this is some post",
            target_usernames: user_2.username,
            is_warning: false
          }

          expect(response).to be_success

          new_topic = Topic.last

          expect(new_topic.title).to eq('This is some post')
          expect(new_topic.is_official_warning?).to eq(false)
        end
      end

      context 'as a normal user' do
        it 'should not be able to mark a topic as warning' do
          post "/posts.json", params: {
            raw: 'this is the test content',
            archetype: 'private_message',
            title: "this is some post",
            target_usernames: user_2.username,
            is_warning: true
          }

          expect(response).to be_success

          new_topic = Topic.last

          expect(new_topic.title).to eq('This is some post')
          expect(new_topic.is_official_warning?).to eq(false)
        end
      end
    end
  end

  describe '#user_posts_feed' do
    it 'returns public posts rss feed' do
      public_post
      private_post

      get "/u/#{user.username}/activity.rss"

      expect(response).to be_success

      body = response.body

      expect(body).to_not include(private_post.url)
      expect(body).to include(public_post.url)
    end
  end

  describe '#latest' do
    context 'private posts' do
      it 'returns private posts rss feed' do
        sign_in(Fabricate(:admin))

        public_post
        private_post
        get "/private-posts.rss"

        expect(response).to be_success

        body = response.body

        expect(body).to include(private_post.url)
        expect(body).to_not include(public_post.url)
      end
    end

    context 'public posts' do
      it 'returns public posts with topic rss feed' do
        public_post
        private_post

        get "/posts.rss"

        expect(response).to be_success

        body = response.body

        expect(body).to include(public_post.url)
        expect(body).to_not include(private_post.url)
      end
    end
  end
end
