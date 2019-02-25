require 'rails_helper'

describe ::Presence::PresencesController do
  before do
    SiteSetting.presence_enabled = true
  end

  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }

  let(:post1) { Fabricate(:post) }
  let(:post2) { Fabricate(:post) }

  let(:manager) { ::Presence::PresenceManager }

  after do
    $redis.del("presence:topic:#{post1.topic.id}")
    $redis.del("presence:topic:#{post2.topic.id}")
    $redis.del("presence:post:#{post1.id}")
    $redis.del("presence:post:#{post2.id}")
  end

  context 'when not logged in' do
    it 'should raise the right error' do
      post '/presence/publish.json'
      expect(response.status).to eq(403)
    end
  end

  context 'when logged in' do
    before do
      sign_in(user1)
    end

    it "doesn't produce an error" do
      expect { post '/presence/publish.json' }.not_to raise_error
    end

    it "does not publish for users with disabled presence features" do
      user1.user_option.update_column(:hide_profile_and_presence, true)
      post '/presence/publish.json'
      expect(response.code).to eq("404")
    end

    it "uses guardian to secure endpoint" do
      private_post = Fabricate(:private_message_post)

      post '/presence/publish.json', params: {
        current: { action: 'edit', post_id: private_post.id }
      }

      expect(response.code.to_i).to eq(403)

      group = Fabricate(:group)
      category = Fabricate(:private_category, group: group)
      private_topic = Fabricate(:topic, category: category)

      post '/presence/publish.json', params: {
        current: { action: 'edit', topic_id: private_topic.id }
      }

      expect(response.code.to_i).to eq(403)
    end

    it "returns a response when requested" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }, response_needed: true
        }
      end

      expect(messages.count).to eq(1)

      data = JSON.parse(response.body)

      expect(data['messagebus_channel']).to eq("/presence/post/#{post1.id}")
      expect(data['messagebus_id']).to eq(MessageBus.last_id("/presence/post/#{post1.id}"))
      expect(data['users'][0]["id"]).to eq(user1.id)
    end

    it "doesn't return a response when not requested" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }
      end

      expect(messages.count).to eq(1)

      data = JSON.parse(response.body)
      expect(data).to eq({})
    end

    it "does send duplicate messagebus messages" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }
      end

      expect(messages.count).to eq(1)

      messages = MessageBus.track_publish do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }
      end

      # we do this cause we also publish time
      expect(messages.count).to eq(1)
    end

    it "clears 'previous' state when supplied" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }

        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post2.id },
          previous: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }
      end

      expect(messages.count).to eq(3)
    end

    it 'cleans up old users when requested' do
      freeze_time Time.zone.now do
        manager.add('topic', post1.topic.id, user2.id)
      end

      # Anything older than 20 seconds should be cleaned up
      freeze_time 30.seconds.from_now do
        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'reply', topic_id: post1.topic.id }, response_needed: true
        }

        data = JSON.parse(response.body)

        expect(data['users'].length).to eq(1)
      end

    end

    describe 'when post has been deleted' do
      it 'should return an empty response' do
        post1.destroy!

        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({})

        post '/presence/publish.json', params: {
          current: { compose_state: 'open', action: 'edit', post_id: post2.id },
          previous: { compose_state: 'open', action: 'edit', post_id: post1.id }
        }

        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)).to eq({})
      end
    end

  end

end
