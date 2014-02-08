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
  end

end

describe 'api' do
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
      lambda do
        put :bookmark, bookmarked: "true", post_id: post.id, api_key: SecureRandom.hex(32), api_username: user.username, format: :json
      end.should raise_error Discourse::NotLoggedIn
    end

    it 'disallows blank api' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      lambda do
        put :bookmark, bookmarked: "true", post_id: post.id, api_key: "", api_username: user.username, format: :json
      end.should raise_error Discourse::NotLoggedIn
    end
  end
end
