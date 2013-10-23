require 'spec_helper'

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
