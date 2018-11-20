require 'rails_helper'

describe ComposerMessagesController do
  let(:topic) { Fabricate(:topic, created_at: 10.years.ago, last_posted_at: 10.years.ago) }
  let(:post) { Fabricate(:post, topic: topic, post_number: 1, created_at: 10.years.ago) }

  context '#index' do
    it 'requires you to be logged in' do
      get "/composer_messages.json"
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      let!(:user) { sign_in(Fabricate(:user)) }
      let(:args) { { 'topic_id' => post.topic.id, 'post_id' => '333', 'composer_action' => 'reply' } }

      it 'redirects to your user preferences' do
        get "/composer_messages.json"
        expect(response.status).to eq(200)
      end

      it 'delegates args to the finder' do
        user.user_stat.update!(post_count: 10)
        SiteSetting.disable_avatar_education_message = true

        get "/composer_messages.json", params: args
        expect(response.status).to eq(200)
        json = JSON.parse(response.body)
        expect(json["composer_messages"].first["id"]).to eq("reviving_old")
      end
    end
  end
end
