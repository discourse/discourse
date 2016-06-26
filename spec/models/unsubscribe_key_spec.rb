require 'rails_helper'
require_dependency 'unsubscribe_key'

describe UnsubscribeKey do

  describe 'post unsubscribe key' do
    it 'can generate a correct url' do
      post = Fabricate(:post)
      url = post.unsubscribe_url(post.user)

      route = Rails.application.routes.recognize_path(url)

      key = UnsubscribeKey.find_by(key: route[:key])

      expect(key.post_id).to eq(post.id)
      expect(key.topic_id).to eq(post.topic_id)
      expect(key.unsubscribe_key_type).to eq("topic")
    end
  end

  describe 'key' do

    let(:user) { Fabricate(:user) }
    let!(:key) { UnsubscribeKey.create_key_for(user, "digest") }

    it 'has a temporary key' do
      expect(key).to be_present
    end

    describe '#user_for_key' do

      it 'can be used to find the user' do
        expect(UnsubscribeKey.user_for_key(key)).to eq(user)
      end

      it 'returns nil with an invalid key' do
        expect(UnsubscribeKey.user_for_key('asdfasdf')).to be_blank
      end

    end

  end

end
