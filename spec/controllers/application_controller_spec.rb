require 'spec_helper'

describe 'api' do
  before do
    fake_key = SecureRandom.hex(32)
    SiteSetting.stubs(:api_key).returns(fake_key)
  end

  describe PostsController do
    let(:user) do
      Fabricate(:user)
    end

    let(:post) do
      Fabricate(:post)
    end

    # choosing an arbitrarily easy to mock trusted activity
    it 'allows users with api key to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).once
      put :bookmark, bookmarked: "true", post_id: post.id, api_key: SiteSetting.api_key, api_username: user.username, format: :json
    end

    it 'disallows phonies to bookmark posts' do
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      lambda do
        put :bookmark, bookmarked: "true", post_id: post.id, api_key: SecureRandom.hex(32), api_username: user.username, format: :json
      end.should raise_error Discourse::NotLoggedIn
    end

    it 'disallows blank api' do
      SiteSetting.stubs(:api_key).returns("")
      PostAction.expects(:act).with(user, post, PostActionType.types[:bookmark]).never
      lambda do
        put :bookmark, bookmarked: "true", post_id: post.id, api_key: "", api_username: user.username, format: :json
      end.should raise_error Discourse::NotLoggedIn
    end
  end
end
