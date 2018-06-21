require 'rails_helper'

describe PostActionUsersController do
  let(:post) { Fabricate(:post, user: sign_in(Fabricate(:user))) }

  context 'with render' do
    it 'always allows you to see your own actions' do
      notify_mod = PostActionType.types[:notify_moderators]

      PostAction.act(post.user, post, notify_mod, message: 'well something is wrong here!')
      PostAction.act(Fabricate(:user), post, notify_mod, message: 'well something is not wrong here!')

      get "/post_action_users.json", params: { id: post.id, post_action_type_id: notify_mod }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      users = json["post_action_users"]

      expect(users.length).to eq(1)
      expect(users[0]["id"]).to eq(post.user.id)
    end
  end

  it 'raises an error without an id' do
    get "/post_action_users.json", params: { post_action_type_id: PostActionType.types[:like] }
    expect(response.status).to eq(400)
  end

  it 'raises an error without a post action type' do
    get "/post_action_users.json", params: { id: post.id }
    expect(response.status).to eq(400)
  end

  it "fails when the user doesn't have permission to see the post" do
    post.trash!
    get "/post_action_users.json", params: {
      id: post.id, post_action_type_id: PostActionType.types[:like]
    }

    expect(response).to be_forbidden
  end

  it 'raises an error when anon tries to look at an invalid action' do
    get "/post_action_users.json", params: {
      id: Fabricate(:post).id,
      post_action_type_id: PostActionType.types[:notify_moderators]
    }

    expect(response).to be_forbidden
  end

  it 'succeeds' do
    get "/post_action_users.json", params: {
      id: post.id, post_action_type_id: PostActionType.types[:like]
    }

    expect(response.status).to eq(200)
  end

  it "paginates post actions" do
    user_ids = []
    5.times do
      user = Fabricate(:user)
      user_ids << user["id"]
      PostAction.act(user, post, PostActionType.types[:like])
    end

    get "/post_action_users.json",
      params: { id: post.id, post_action_type_id: PostActionType.types[:like], page: 1, limit: 2 }
    json = JSON.parse(response.body)

    users = json["post_action_users"]
    total = json["total_rows_post_action_users"]

    expect(users.length).to eq(2)
    expect(users.map { |u| u["id"] }).to eq(user_ids[2..3])

    expect(total).to eq(5)
  end
end
