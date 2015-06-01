require 'spec_helper'

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

  it "doesn't store an incoming link when there's no referer" do
    expect {
      get :show, id: topic.id
    }.not_to change(IncomingLink, :count)
  end

  it "doesn't raise an error on a very long link" do
    set_referer("http://#{'a' * 2000}.com")
    expect { get :show, {id: topic.id} }.not_to raise_error
  end

  describe "has_escaped_fragment?" do
    render_views

    context "when the SiteSetting is disabled" do
      before do
        SiteSetting.stubs(:enable_escaped_fragments?).returns(false)
      end

      it "uses the application layout even with an escaped fragment param" do
        get :show, {'topic_id' => topic.id, 'slug' => topic.slug,  '_escaped_fragment_' => 'true'}
        expect(response).to render_template(layout: 'application')
        assert_select "meta[name=fragment]", false, "it doesn't have the meta tag"
      end
    end

    context "when the SiteSetting is enabled" do
      before do
        SiteSetting.stubs(:enable_escaped_fragments?).returns(true)
      end

      it "uses the application layout when there's no param" do
        get :show, topic_id: topic.id, slug: topic.slug
        expect(response).to render_template(layout: 'application')
        assert_select "meta[name=fragment]", true, "it has the meta tag"
      end

      it "uses the crawler layout when there's an _escaped_fragment_ param" do
        get :show, topic_id: topic.id, slug: topic.slug,  _escaped_fragment_: 'true'
        expect(response).to render_template(layout: 'crawler')
        assert_select "meta[name=fragment]", false, "it doesn't have the meta tag"
      end
    end
  end

  describe "crawler" do
    render_views

    context "when not a crawler" do
      before do
        CrawlerDetection.expects(:crawler?).returns(false)
      end
      it "renders with the application layout" do
        get :show, topic_id: topic.id, slug: topic.slug
        expect(response).to render_template(layout: 'application')
        assert_select "meta[name=fragment]", true, "it has the meta tag"
      end
    end

    context "when a crawler" do
      before do
        CrawlerDetection.expects(:crawler?).returns(true)
      end
      it "renders with the crawler layout" do
        get :show, topic_id: topic.id, slug: topic.slug
        expect(response).to render_template(layout: 'crawler')
        assert_select "meta[name=fragment]", false, "it doesn't have the meta tag"
      end
    end

  end

  describe 'set_locale' do
    it 'sets the one the user prefers' do
      SiteSetting.stubs(:allow_user_locale).returns(true)

      user = Fabricate(:user, locale: :fr)
      log_in_user(user)

      get :show, {topic_id: topic.id}

      expect(I18n.locale).to eq(:fr)
    end

    it 'is sets the default locale when the setting not enabled' do
      user = Fabricate(:user, locale: :fr)
      log_in_user(user)

      get :show, {topic_id: topic.id}

      expect(I18n.locale).to eq(:en)
    end
  end

  describe "read only header" do
    it "returns no read only header by default" do
      get :show, {topic_id: topic.id}
      expect(response.headers['Discourse-Readonly']).to eq(nil)
    end

    it "returns a readonly header if the site is read only" do
      Discourse.received_readonly!
      get :show, {topic_id: topic.id}
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
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: api_key.key, format: :json
      expect(response).to be_success
    end

    it 'raises an error with a user key that does not match an optionally specified username' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: api_key.key, api_username: 'made_up', format: :json
      expect(response).not_to be_success
    end

    it 'allows users with a master api key to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).once
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: master_key.key, api_username: user.username, format: :json
      expect(response).to be_success
    end

    it 'disallows phonies to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: SecureRandom.hex(32), api_username: user.username, format: :json
      expect(response.code.to_i).to eq(403)
    end

    it 'disallows blank api' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: "", api_username: user.username, format: :json
      expect(response.code.to_i).to eq(403)
    end
  end
end
