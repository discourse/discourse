require 'rails_helper'

RSpec.describe EmailController do
  let(:user) { Fabricate(:user) }
  let(:topic) { Fabricate(:topic) }
  let(:private_topic) { Fabricate(:private_message_topic) }

  context '.perform unsubscribe' do
    it 'raises not found on invalid key' do
      post "/email/unsubscribe/123.json"
      expect(response.status).to eq(404)
    end

    it 'can fully unsubscribe' do
      user = Fabricate(:user)
      key = UnsubscribeKey.create_key_for(user, "all")

      user.user_option.update_columns(email_always: true,
                                      email_digests: true,
                                      email_direct: true,
                                      email_private_messages: true)

      post "/email/unsubscribe/#{key}.json",
        params: { unsubscribe_all: "1" }

      expect(response.status).to eq(302)

      get response.redirect_url

      # cause it worked ... yay
      expect(body).to include(user.email)

      user.user_option.reload

      expect(user.user_option.email_always).to eq(false)
      expect(user.user_option.email_digests).to eq(false)
      expect(user.user_option.email_direct).to eq(false)
      expect(user.user_option.email_private_messages).to eq(false)

    end

    it 'can disable mailing list' do
      user = Fabricate(:user)
      key = UnsubscribeKey.create_key_for(user, "all")

      user.user_option.update_columns(mailing_list_mode: true)

      post "/email/unsubscribe/#{key}.json",
        params: { disable_mailing_list: "1" }

      expect(response.status).to eq(302)

      user.user_option.reload

      expect(user.user_option.mailing_list_mode).to eq(false)
    end

    it 'can disable digest' do
      user = Fabricate(:user)
      key = UnsubscribeKey.create_key_for(user, "all")

      user.user_option.update_columns(email_digests: true)

      post "/email/unsubscribe/#{key}.json",
        params: { disable_digest_emails: "1" }

      expect(response.status).to eq(302)

      user.user_option.reload

      expect(user.user_option.email_digests).to eq(false)
    end

    it 'can unwatch topic' do
      p = Fabricate(:post)
      key = UnsubscribeKey.create_key_for(p.user, p)

      TopicUser.change(p.user_id, p.topic_id, notification_level: TopicUser.notification_levels[:watching])

      post "/email/unsubscribe/#{key}.json",
        params: { unwatch_topic: "1" }

      expect(response.status).to eq(302)

      expect(TopicUser.get(p.topic, p.user).notification_level).to eq(TopicUser.notification_levels[:tracking])
    end

    it 'can mute topic' do
      p = Fabricate(:post)
      key = UnsubscribeKey.create_key_for(p.user, p)

      TopicUser.change(p.user_id, p.topic_id, notification_level: TopicUser.notification_levels[:watching])

      post "/email/unsubscribe/#{key}.json",
        params: { mute_topic: "1" }

      expect(response.status).to eq(302)

      expect(TopicUser.get(p.topic, p.user).notification_level).to eq(TopicUser.notification_levels[:muted])
    end

    it 'can unwatch category' do
      p = Fabricate(:post)
      key = UnsubscribeKey.create_key_for(p.user, p)

      cu = CategoryUser.create!(user_id: p.user.id,
                                category_id: p.topic.category_id,
                                notification_level: CategoryUser.notification_levels[:watching])

      post "/email/unsubscribe/#{key}.json",
        params: { unwatch_category: "1" }

      expect(response.status).to eq(302)

      expect(CategoryUser.find_by(id: cu.id)).to eq(nil)
    end

    it 'can unwatch first post from category' do
      p = Fabricate(:post)
      key = UnsubscribeKey.create_key_for(p.user, p)

      cu = CategoryUser.create!(user_id: p.user.id,
                                category_id: p.topic.category_id,
                                notification_level: CategoryUser.notification_levels[:watching_first_post])

      post "/email/unsubscribe/#{key}.json",
        params: { unwatch_category: "1" }

      expect(response.status).to eq(302)

      expect(CategoryUser.find_by(id: cu.id)).to eq(nil)
    end
  end

  describe '#unsubscribed' do
    describe 'when email is invalid' do
      it 'should return the right response' do
        get '/email/unsubscribed', params: { email: 'somerandomstring' }
        expect(response.status).to eq(404)
      end
    end

    describe 'when topic is public' do
      it 'should return the right response' do
        key = SecureRandom.hex
        $redis.set(key, user.email)
        get '/email/unsubscribed', params: { key: key, topic_id: topic.id }
        expect(response).to be_success
        expect(response.body).to include(topic.title)
      end
    end

    describe 'when topic is private' do
      it 'should return the right response' do
        key = SecureRandom.hex
        $redis.set(key, user.email)
        get '/email/unsubscribed', params: { key: key, topic_id: private_topic.id }
        expect(response).to be_success
        expect(response.body).to_not include(private_topic.title)
      end
    end
  end
end
