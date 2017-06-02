require 'rails_helper'

describe PostActionUsersController do
  let(:post) { Fabricate(:post, user: log_in) }

  context 'with render' do
    render_views
    it 'always allows you to see your own actions' do
      notify_mod = PostActionType.types[:notify_moderators]

      PostAction.act(post.user, post, notify_mod, message: 'well something is wrong here!')
      PostAction.act(Fabricate(:user), post, notify_mod, message: 'well something is not wrong here!')

      xhr :get, :index, id: post.id, post_action_type_id: notify_mod
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      users = json["post_action_users"]

      expect(users.length).to eq(1)
      expect(users[0]["id"]).to eq(post.user.id)
    end
  end

  it 'raises an error without an id' do
    expect {
      xhr :get, :index, post_action_type_id: PostActionType.types[:like]
    }.to raise_error(ActionController::ParameterMissing)
  end

  it 'raises an error without a post action type' do
    expect {
      xhr :get, :index, id: post.id
    }.to raise_error(ActionController::ParameterMissing)
  end

  it "fails when the user doesn't have permission to see the post" do
    Guardian.any_instance.expects(:can_see?).with(post).returns(false)
    xhr :get, :index, id: post.id, post_action_type_id: PostActionType.types[:like]
    expect(response).to be_forbidden
  end

  it 'raises an error when anon tries to look at an invalid action' do
    xhr :get, :index, id: Fabricate(:post).id, post_action_type_id: PostActionType.types[:notify_moderators]
    expect(response).to be_forbidden
  end

  it 'succeeds' do
    xhr :get, :index, id: post.id, post_action_type_id: PostActionType.types[:like]
    expect(response).to be_success
  end
end
