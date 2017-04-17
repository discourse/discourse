require 'rails_helper'

RSpec.describe "Managing a topic's status update", type: :request do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }

  context 'when a user is not logged in' do
    it 'should return the right response' do
      expect do
        post "/t/#{topic.id}/status_update.json",
          time: '24',
          status_type: TopicStatusUpdate.types[1]
      end.to raise_error(Discourse::NotLoggedIn)
    end
  end

  context 'when does not have permission' do
    it 'should return the right response' do
      sign_in(user)

      post "/t/#{topic.id}/status_update.json",
        time: '24',
        status_type: TopicStatusUpdate.types[1]

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
      time = 24

      post "/t/#{topic.id}/status_update.json",
        time: 24,
        status_type: TopicStatusUpdate.types[1]

      expect(response).to be_success

      topic_status_update = TopicStatusUpdate.last

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
      topic.update!(topic_status_updates: [Fabricate(:topic_status_update)])

      post "/t/#{topic.id}/status_update.json",
        time: nil,
        status_type: TopicStatusUpdate.types[1]

      expect(response).to be_success
      expect(topic.reload.topic_status_update).to eq(nil)

      json = JSON.parse(response.body)

      expect(json['execute_at']).to eq(nil)
      expect(json['duration']).to eq(nil)
      expect(json['closed']).to eq(topic.closed)
    end

    describe 'publishing topic to category in the future' do
      it 'should be able to create the topic status update' do
        SiteSetting.queue_jobs = true

        post "/t/#{topic.id}/status_update.json",
          time: 24,
          status_type: TopicStatusUpdate.types[3],
          category_id: topic.category_id

        expect(response).to be_success

        topic_status_update = TopicStatusUpdate.last

        expect(topic_status_update.topic).to eq(topic)

        expect(topic_status_update.execute_at)
          .to be_within(1.second).of(24.hours.from_now)

        expect(topic_status_update.status_type)
          .to eq(TopicStatusUpdate.types[:publish_to_category])

        json = JSON.parse(response.body)

        expect(json['category_id']).to eq(topic.category_id)
      end
    end

    describe 'invalid status type' do
      it 'should raise the right error' do
        expect do
          post "/t/#{topic.id}/status_update.json",
            time: 10,
            status_type: 'something'
        end.to raise_error(Discourse::InvalidParameters)
      end
    end
  end
end
