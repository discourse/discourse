require 'rails_helper'

RSpec.describe EmailController do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic) }
  let(:private_topic) { Fabricate(:private_message_topic) }

  describe '#unsubscribed' do
    describe 'when email is invalid' do
      it 'should return the right response' do
        get '/email/unsubscribed', params: { email: 'somerandomstring' }
        expect(response.status).to eq(404)
      end
    end

    describe 'when topic is public' do
      it 'should return the right response' do
        get '/email/unsubscribed', params: { email: user.email, topic_id: topic.id }
        expect(response).to be_success
        expect(response.body).to include(topic.title)
      end
    end

    describe 'when topic is private' do
      it 'should return the right response' do
        get '/email/unsubscribed', params: { email: user.email, topic_id: private_topic.id }
        expect(response).to be_success
        expect(response.body).to_not include(private_topic.title)
      end
    end
  end
end
