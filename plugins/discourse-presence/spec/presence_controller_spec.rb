require 'rails_helper'

describe ::Presence::PresencesController, type: :request do

  before do
    SiteSetting.presence_enabled = true
  end

  let(:user1) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }
  let(:user3) { Fabricate(:user) }

  after(:each) do
    $redis.del('presence:post:22')
    $redis.del('presence:post:11')
  end

  context 'when not logged in' do
    it 'should raise the right error' do
      expect { post '/presence/publish.json' }.to raise_error(Discourse::NotLoggedIn)
    end
  end

  context 'when logged in' do
    before do
      sign_in(user1)
    end

    it "doesn't produce an error" do
      expect { post '/presence/publish.json' }.not_to raise_error
    end

    it "returns a response when requested" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 22 }, response_needed: true
      end

      expect(messages.count).to eq (1)

      data = JSON.parse(response.body)

      expect(data['messagebus_channel']).to eq('/presence/post/22')
      expect(data['messagebus_id']).to eq(MessageBus.last_id('/presence/post/22'))
      expect(data['users'][0]["id"]).to eq(user1.id)
    end

    it "doesn't return a response when not requested" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 22 }
      end

      expect(messages.count).to eq (1)

      data = JSON.parse(response.body)
      expect(data).to eq({})
    end

    it "doesn't send duplicate messagebus messages" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 22 }
      end
      expect(messages.count).to eq (1)

      messages = MessageBus.track_publish do
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 22 }
      end
      expect(messages.count).to eq (0)
    end

    it "clears 'previous' state when supplied" do
      messages = MessageBus.track_publish do
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 22 }
        post '/presence/publish.json', current: { compose_state: 'open', action: 'edit', post_id: 11 }, previous: { compose_state: 'open', action: 'edit', post_id: 22 }
      end
      expect(messages.count).to eq (3)
    end

  end

end
