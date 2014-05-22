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
    lambda {
      get :show, id: topic.id
    }.should_not change(IncomingLink, :count)
  end

  it "doesn't raise an error on a very long link" do
    set_referer("http://#{'a' * 2000}.com")
    lambda { get :show, {id: topic.id} }.should_not raise_error
  end

  it "stores an incoming link when there is an off-site referer" do
    lambda {
      set_referer("http://google.com/search")
      get :show, {id: topic.id}
    }.should change(IncomingLink, :count).by(1)
  end

  describe "has_escaped_fragment?" do
    render_views

    context "when the SiteSetting is disabled" do
      before do
        SiteSetting.stubs(:enable_escaped_fragments?).returns(false)
      end

      it "uses the application layout even with an escaped fragment param" do
        get :show, {'id' => topic.id, '_escaped_fragment_' => 'true'}
        response.should render_template(layout: 'application')
        assert_select "meta[name=fragment]", false, "it doesn't have the meta tag"
      end
    end

    context "when the SiteSetting is enabled" do
      before do
        SiteSetting.stubs(:enable_escaped_fragments?).returns(true)
      end

      it "uses the application layout when there's no param" do
        get :show, {'id' => topic.id}
        response.should render_template(layout: 'application')
        assert_select "meta[name=fragment]", true, "it has the meta tag"
      end

      it "uses the crawler layout when there's an _escaped_fragment_ param" do
        get :show, {'id' => topic.id, '_escaped_fragment_' => 'true'}
        response.should render_template(layout: 'crawler')
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
        get :show, {'id' => topic.id}
        response.should render_template(layout: 'application')
        assert_select "meta[name=fragment]", true, "it has the meta tag"
      end
    end

    context "when a crawler" do
      before do
        CrawlerDetection.expects(:crawler?).returns(true)
      end
      it "renders with the crawler layout" do
        get :show, {'id' => topic.id}
        response.should render_template(layout: 'crawler')
        assert_select "meta[name=fragment]", false, "it doesn't have the meta tag"
      end
    end

  end

  describe 'after inserting an incoming link' do

    it 'sets last link correctly' do
      set_referer("http://google.com/search")
      get :show, {topic_id: topic.id}

      last_link = IncomingLink.last
      last_link.topic_id.should == topic.id
      last_link.post_number.should == 1
    end

  end

  describe 'set_locale' do
    it 'sets the one the user prefers' do
      SiteSetting.stubs(:allow_user_locale).returns(true)

      user = Fabricate(:user, locale: :fr)
      log_in_user(user)

      get :show, {topic_id: topic.id}

      I18n.locale.should == :fr
    end

    it 'is sets the default locale when the setting not enabled' do
      user = Fabricate(:user, locale: :fr)
      log_in_user(user)

      get :show, {topic_id: topic.id}

      I18n.locale.should == :en
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
      response.should be_success
    end

    it 'raises an error with a user key that does not match an optionally specified username' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: api_key.key, api_username: 'made_up', format: :json
      response.should_not be_success
    end

    it 'allows users with a master api key to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).once
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: master_key.key, api_username: user.username, format: :json
      response.should be_success
    end

    it 'disallows phonies to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: SecureRandom.hex(32), api_username: user.username, format: :json
      response.code.to_i.should == 403
    end

    it 'disallows blank api' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: "", api_username: user.username, format: :json
      response.code.to_i.should == 403
    end
  end
end
