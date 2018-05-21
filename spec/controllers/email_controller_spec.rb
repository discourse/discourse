require 'rails_helper'

describe EmailController do

  context '.preferences_redirect' do

    it 'requires you to be logged in' do
      get :preferences_redirect, format: :json
      expect(response.status).to eq(403)
    end

    context 'when logged in' do
      let!(:user) { log_in }

      it 'redirects to your user preferences' do
        get :preferences_redirect, format: :json
        expect(response).to redirect_to("/u/#{user.username}/preferences")
      end
    end

  end

  context '.unsubscribe' do

    render_views

    it 'displays logo ut button if wrong user logged in' do
      log_in_user Fabricate(:admin)
      user = Fabricate(:user)
      key = UnsubscribeKey.create_key_for(user, "digest")

      get :unsubscribe, params: { key: key }

      expect(response.body).to include(I18n.t("unsubscribe.log_out"))
      expect(response.body).to include(I18n.t("unsubscribe.different_user_description"))
    end

    it 'displays not found if key is not found' do
      get :unsubscribe, params: { key: SecureRandom.hex }
      expect(response.body).to include(CGI.escapeHTML(I18n.t("unsubscribe.not_found_description")))
    end

    it 'correctly handles mailing list mode' do

      user = Fabricate(:user)
      key = UnsubscribeKey.create_key_for(user, "digest")

      user.user_option.update_columns(mailing_list_mode: true)

      get :unsubscribe, params: { key: key }
      expect(response.body).to include(I18n.t("unsubscribe.mailing_list_mode"))

      SiteSetting.disable_mailing_list_mode = true

      get :unsubscribe, params: { key: key }
      expect(response.body).not_to include(I18n.t("unsubscribe.mailing_list_mode"))

      user.user_option.update_columns(mailing_list_mode: false)
      SiteSetting.disable_mailing_list_mode = false

      get :unsubscribe, params: { key: key }
      expect(response.body).not_to include(I18n.t("unsubscribe.mailing_list_mode"))

    end

    it 'correctly handles digest unsubscribe' do

      user = Fabricate(:user)
      user.user_option.update_columns(email_digests: false)
      key = UnsubscribeKey.create_key_for(user, "digest")

      # because we are type digest we will always show digest and it will be selected
      get :unsubscribe, params: { key: key }
      expect(response.body).to include(I18n.t("unsubscribe.disable_digest_emails"))

      source = Nokogiri::HTML::fragment(response.body)
      expect(source.css("#disable_digest_emails")[0]["checked"]).to eq("checked")

      SiteSetting.disable_digest_emails = true

      get :unsubscribe, params: { key: key }
      expect(response.body).not_to include(I18n.t("unsubscribe.disable_digest_emails"))

      SiteSetting.disable_digest_emails = false
      key = UnsubscribeKey.create_key_for(user, "not_digest")

      get :unsubscribe, params: { key: key }
      expect(response.body).to include(I18n.t("unsubscribe.disable_digest_emails"))
    end

    it 'correctly handles watched categories' do
      post = Fabricate(:post)
      user = post.user
      cu = CategoryUser.create!(user_id: user.id,
                                category_id: post.topic.category_id,
                                notification_level: CategoryUser.notification_levels[:watching])

      key = UnsubscribeKey.create_key_for(user, post)
      get :unsubscribe, params: { key: key }
      expect(response.body).to include("unwatch_category")

      cu.destroy!

      get :unsubscribe, params: { key: key }
      expect(response.body).not_to include("unwatch_category")

    end

    it 'correctly handles watched first post categories' do
      post = Fabricate(:post)
      user = post.user
      cu = CategoryUser.create!(user_id: user.id,
                                category_id: post.topic.category_id,
                                notification_level: CategoryUser.notification_levels[:watching_first_post])

      key = UnsubscribeKey.create_key_for(user, post)
      get :unsubscribe, params: { key: key }
      expect(response.body).to include("unwatch_category")

      cu.destroy!

      get :unsubscribe, params: { key: key }
      expect(response.body).not_to include("unwatch_category")

    end
  end

end
