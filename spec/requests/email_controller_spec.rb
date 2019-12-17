# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmailController do
  fab!(:user) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic) }
  fab!(:private_topic) { Fabricate(:private_message_topic) }

  context '.perform unsubscribe' do
    it 'raises not found on invalid key' do
      post "/email/unsubscribe/123.json"
      expect(response.status).to eq(404)
    end

    fab!(:user) { Fabricate(:user) }
    let(:key) { UnsubscribeKey.create_key_for(user, "all") }

    it 'can fully unsubscribe' do
      user.user_option.update_columns(email_digests: true,
                                      email_level: UserOption.email_level_types[:never],
                                      email_messages_level: UserOption.email_level_types[:never])

      post "/email/unsubscribe/#{key}.json",
        params: { unsubscribe_all: "1" }

      expect(response.status).to eq(302)

      get response.redirect_url

      # cause it worked ... yay
      expect(body).to include(user.email)

      user.user_option.reload

      expect(user.user_option.email_digests).to eq(false)
      expect(user.user_option.email_level).to eq(UserOption.email_level_types[:never])
      expect(user.user_option.email_messages_level).to eq(UserOption.email_level_types[:never])
    end

    it 'can disable mailing list' do
      user.user_option.update_columns(mailing_list_mode: true)

      post "/email/unsubscribe/#{key}.json",
        params: { disable_mailing_list: "1" }

      expect(response.status).to eq(302)

      user.user_option.reload

      expect(user.user_option.mailing_list_mode).to eq(false)
    end

    it 'Can change digest frequency' do
      weekly_interval_minutes = 10080
      user.user_option.update_columns(email_digests: true, digest_after_minutes: 0)

      post "/email/unsubscribe/#{key}.json",
        params: { digest_after_minutes: weekly_interval_minutes.to_s }

      expect(response.status).to eq(302)

      user.user_option.reload

      expect(user.user_option.digest_after_minutes).to eq(weekly_interval_minutes)
    end

    it 'Can disable email digests setting frequency to zero' do
      user.user_option.update_columns(email_digests: true, digest_after_minutes: 10080)

      post "/email/unsubscribe/#{key}.json",
        params: { digest_after_minutes: '0' }

      expect(response.status).to eq(302)

      user.user_option.reload

      expect(user.user_option.digest_after_minutes).to be_zero
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
        Discourse.cache.write(key, user.email)
        get '/email/unsubscribed', params: { key: key, topic_id: topic.id }
        expect(response.status).to eq(200)
        expect(response.body).to include(topic.title)
      end
    end

    describe 'when topic is private' do
      it 'should return the right response' do
        key = SecureRandom.hex
        Discourse.cache.write(key, user.email)
        get '/email/unsubscribed', params: { key: key, topic_id: private_topic.id }
        expect(response.status).to eq(200)
        expect(response.body).to_not include(private_topic.title)
      end
    end
  end

  context '#preferences_redirect' do
    it 'requires you to be logged in' do
      get "/email_preferences.json"
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      let!(:user) { sign_in(Fabricate(:user)) }

      it 'redirects to your user preferences' do
        get "/email_preferences.json"
        expect(response).to redirect_to("/u/#{user.username}/preferences")
      end
    end
  end

  context '#unsubscribe' do
    it 'displays not found if key is not found' do
      navigate_to_unsubscribe(SecureRandom.hex)

      expect(response.body).to include(CGI.escapeHTML(I18n.t("unsubscribe.not_found_description")))
    end

    fab!(:user) { Fabricate(:user) }
    let(:unsubscribe_key) { UnsubscribeKey.create_key_for(user, key_type) }

    context 'Unsubscribe from digest' do
      let(:key_type) { 'digest' }

      it 'displays log out button if wrong user logged in' do
        sign_in(Fabricate(:admin))

        navigate_to_unsubscribe

        expect(response.body).to include(I18n.t("unsubscribe.log_out"))
        expect(response.body).to include(I18n.t("unsubscribe.different_user_description"))
      end

      it 'correctly handles mailing list mode' do
        user.user_option.update_columns(mailing_list_mode: true)

        navigate_to_unsubscribe
        expect(response.body).to include(I18n.t("unsubscribe.mailing_list_mode"))

        SiteSetting.disable_mailing_list_mode = true

        navigate_to_unsubscribe
        expect(response.body).not_to include(I18n.t("unsubscribe.mailing_list_mode"))

        user.user_option.update_columns(mailing_list_mode: false)
        SiteSetting.disable_mailing_list_mode = false

        navigate_to_unsubscribe
        expect(response.body).not_to include(I18n.t("unsubscribe.mailing_list_mode"))
      end

      it 'Lets you select the digest frequency ranging from never to half a year' do
        selected_digest_frequency = 0
        slow_digest_frequencies = ['weekly', 'every month', 'every six months', 'never']

        navigate_to_unsubscribe

        source = Nokogiri::HTML::fragment(response.body)
        expect(source.css(".combobox option").map(&:inner_text)).to eq(slow_digest_frequencies)
      end

      it 'Selects the next slowest frequency by default' do
        every_month_freq = 43200
        six_months_freq = 259200
        user.user_option.update_columns(digest_after_minutes: every_month_freq)

        navigate_to_unsubscribe

        source = Nokogiri::HTML::fragment(response.body)
        expect(source.css(".combobox option[selected='selected']")[0]['value']).to eq(six_months_freq.to_s)
      end

      it 'Uses never as the selected frequency if current one is six months' do
        never_frequency = 0
        six_months_freq = 259200
        user.user_option.update_columns(digest_after_minutes: six_months_freq)

        navigate_to_unsubscribe

        source = Nokogiri::HTML::fragment(response.body)
        expect(source.css(".combobox option[selected='selected']")[0]['value']).to eq(never_frequency.to_s)
      end
    end

    context 'Unsubscribe from a post' do
      fab!(:post) { Fabricate(:post) }
      let(:user) { post.user }
      let(:key_type) { post }

      it 'correctly handles watched categories' do
        cu = create_category_user(:watching)

        navigate_to_unsubscribe
        expect(response.body).to include("unwatch_category")

        cu.destroy!

        navigate_to_unsubscribe
        expect(response.body).not_to include("unwatch_category")
      end

      it 'correctly handles watched first post categories' do
        cu = create_category_user(:watching_first_post)

        navigate_to_unsubscribe
        expect(response.body).to include("unwatch_category")

        cu.destroy!

        navigate_to_unsubscribe
        expect(response.body).not_to include("unwatch_category")
      end

      def create_category_user(notification_level)
        CategoryUser.create!(
          user_id: user.id,
          category_id: post.topic.category_id,
          notification_level: CategoryUser.notification_levels[notification_level]
        )
      end
    end

    def navigate_to_unsubscribe(key = unsubscribe_key)
      get "/email/unsubscribe/#{key}"
    end
  end
end
