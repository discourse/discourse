require 'rails_helper'

describe TopicsController do
  before do
    TopicUser.stubs(:track_visit!)
  end

  let :topic do
    Fabricate(:post).topic
  end

  def set_referer(ref)
    request.env['HTTP_REFERER'] = ref
  end

  def set_accept_language(locale)
    request.env['HTTP_ACCEPT_LANGUAGE'] = locale
  end

  describe "themes" do
    let :theme do
      Theme.create!(user_id: -1, name: 'bob', user_selectable: true)
    end

    let :theme2 do
      Theme.create!(user_id: -1, name: 'bobbob', user_selectable: true)
    end

    it "selects the theme the user has selected" do
      user = log_in
      user.user_option.update_columns(theme_key: theme.key)

      get :show, params: { id: 666 }
      expect(controller.theme_key).to eq(theme.key)

      theme.update_attribute(:user_selectable, false)

      get :show, params: { id: 666 }
      expect(controller.theme_key).not_to eq(theme.key)
    end

    it "can be overridden with a cookie" do
      user = log_in
      user.user_option.update_columns(theme_key: theme.key)

      cookies['theme_key'] = "#{theme2.key},#{user.user_option.theme_key_seq}"

      get :show, params: { id: 666 }
      expect(controller.theme_key).to eq(theme2.key)

    end

    it "cookie can fail back to user if out of sync" do
      user = log_in
      user.user_option.update_columns(theme_key: theme.key)
      cookies['theme_key'] = "#{theme2.key},#{user.user_option.theme_key_seq - 1}"

      get :show, params: { id: 666 }
      expect(controller.theme_key).to eq(theme.key)
    end
  end

  it "doesn't store an incoming link when there's no referer" do
    expect {
      get :show, params: { id: topic.id }, format: :json
    }.not_to change(IncomingLink, :count)
  end

  it "doesn't raise an error on a very long link" do
    set_referer("http://#{'a' * 2000}.com")

    expect do
      get :show, params: { id: topic.id }, format: :json
    end.not_to raise_error
  end

  describe "has_escaped_fragment?" do
    render_views

    context "when the SiteSetting is disabled" do

      it "uses the application layout even with an escaped fragment param" do
        SiteSetting.enable_escaped_fragments = false

        get :show, params: {
          'topic_id' => topic.id,
          'slug' => topic.slug,
          '_escaped_fragment_' => 'true'
        }

        body = response.body

        expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
      end

    end

    context "when the SiteSetting is enabled" do
      before do
        SiteSetting.enable_escaped_fragments = true
      end

      it "uses the application layout when there's no param" do
        get :show, params: { topic_id: topic.id, slug: topic.slug }

        body = response.body

        expect(body).to have_tag(:script, with: { src: '/assets/application.js' })
        expect(body).to have_tag(:meta, with: { name: 'fragment' })
      end

      it "uses the crawler layout when there's an _escaped_fragment_ param" do
        get :show, params: {
          topic_id: topic.id,
          slug: topic.slug,
          _escaped_fragment_: 'true'
        }

        body = response.body

        expect(body).to have_tag(:body, with: { class: 'crawler' })
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
      end
    end
  end

  describe "print" do
    render_views

    context "when the SiteSetting is enabled" do
      it "uses the application layout when there's no param" do
        get :show, params: { topic_id: topic.id, slug: topic.slug }

        body = response.body

        expect(body).to have_tag(:script, src: '/assets/application.js')
        expect(body).to have_tag(:meta, with: { name: 'fragment' })
      end

      it "uses the crawler layout when there's an print param" do
        get :show, params: { topic_id: topic.id, slug: topic.slug, print: 'true' }

        body = response.body

        expect(body).to have_tag(:body, class: 'crawler')
        expect(body).to_not have_tag(:meta, with: { name: 'fragment' })
      end
    end
  end

  describe 'clear_notifications' do
    it 'correctly clears notifications if specified via cookie' do
      notification = Fabricate(:notification)
      log_in_user(notification.user)

      request.cookies['cn'] = "2828,100,#{notification.id}"

      get :show, params: { topic_id: 100, format: :json }

      expect(response.cookies['cn']).to eq nil

      notification.reload
      expect(notification.read).to eq true

    end

    it 'correctly clears notifications if specified via header' do
      notification = Fabricate(:notification)
      log_in_user(notification.user)

      request.headers['Discourse-Clear-Notifications'] = "2828,100,#{notification.id}"

      get :show, params: { topic_id: 100, format: :json }

      notification.reload
      expect(notification.read).to eq true
    end
  end

  describe "set_locale" do
    context "allow_user_locale disabled" do
      context "accept-language header differs from default locale" do
        before do
          SiteSetting.allow_user_locale = false
          SiteSetting.default_locale = "en"
          set_accept_language("fr")
        end

        context "with an anonymous user" do
          it "uses the default locale" do
            get :show, params: { topic_id: topic.id, format: :json }

            expect(I18n.locale).to eq(:en)
          end
        end

        context "with a logged in user" do
          it "it uses the default locale" do
            user = Fabricate(:user, locale: :fr)
            log_in_user(user)

            get :show, params: { topic_id: topic.id, format: :json }

            expect(I18n.locale).to eq(:en)
          end
        end
      end
    end

    context "set_locale_from_accept_language_header enabled" do
      context "accept-language header differs from default locale" do
        before do
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_accept_language_header = true
          SiteSetting.default_locale = "en"
          set_accept_language("fr")
        end

        context "with an anonymous user" do
          it "uses the locale from the headers" do
            get :show, params: { topic_id: topic.id, format: :json }

            expect(I18n.locale).to eq(:fr)
          end
        end

        context "with a logged in user" do
          it "uses the user's preferred locale" do
            user = Fabricate(:user, locale: :fr)
            log_in_user(user)

            get :show, params: { topic_id: topic.id, format: :json }

            expect(I18n.locale).to eq(:fr)
          end
        end
      end

      context "the preferred locale includes a region" do
        it "returns the locale and region separated by an underscore" do
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_accept_language_header = true
          SiteSetting.default_locale = "en"
          set_accept_language("zh-CN")

          get :show, params: { topic_id: topic.id, format: :json }

          expect(I18n.locale).to eq(:zh_CN)
        end
      end

      context 'accept-language header is not set' do
        it 'uses the site default locale' do
          SiteSetting.allow_user_locale = true
          SiteSetting.default_locale = 'en'
          set_accept_language('')

          get :show, params: { topic_id: topic.id, format: :json }

          expect(I18n.locale).to eq(:en)
        end
      end
    end
  end

  describe "read only header" do
    it "returns no read only header by default" do
      get :show, params: { topic_id: topic.id, format: :json }
      expect(response.headers['Discourse-Readonly']).to eq(nil)
    end

    it "returns a readonly header if the site is read only" do
      Discourse.received_readonly!
      get :show, params: { topic_id: topic.id, format: :json }
      expect(response.headers['Discourse-Readonly']).to eq('true')
    end
  end
end

describe 'api' do

  before do
    ActionController::Base.allow_forgery_protection = true
  end

  after do
    ActionController::Base.allow_forgery_protection = false
  end

  describe PostsController do
    let(:user) do
      Fabricate(:user)
    end

    let(:post) do
      Fabricate(:post)
    end

    let(:api_key) { user.generate_api_key(user) }
    let(:master_key) { ApiKey.create_master_key }

    # choosing an arbitrarily easy to mock trusted activity
    it 'allows users with api key to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).once

      put :bookmark, params: {
        bookmarked: "true",
        post_id: post.id,
        api_key: api_key.key
      }, format: :json

      expect(response).to be_success
    end

    it 'raises an error with a user key that does not match an optionally specified username' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never

      put :bookmark, params: {
        bookmarked: "true",
        post_id: post.id,
        api_key: api_key.key,
        api_username: 'made_up'
      }, format: :json

      expect(response).not_to be_success
    end

    it 'allows users with a master api key to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).once

      put :bookmark, params: {
        bookmarked: "true",
        post_id: post.id,
        api_key: master_key.key,
        api_username: user.username
      }, format: :json

      expect(response).to be_success
    end

    it 'disallows phonies to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never

      put :bookmark, params: {
        bookmarked: "true",
        post_id: post.id,
        api_key: SecureRandom.hex(32),
        api_username: user.username
      }, format: :json

      expect(response.code.to_i).to eq(403)
    end

    it 'disallows blank api' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never

      put :bookmark, params: {
        bookmarked: "true",
        post_id: post.id,
        api_key: "",
        api_username: user.username
      }, format: :json

      expect(response.code.to_i).to eq(403)
    end
  end
end
