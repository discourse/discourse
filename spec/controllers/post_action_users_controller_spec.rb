require 'rails_helper'

describe PostActionUsersController do
  let!(:post) { Fabricate(:post, user: log_in) }

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

  it 'raises an error when the post action type cannot be seen' do
    Guardian.any_instance.expects(:can_see_post_actors?).with(instance_of(Topic), PostActionType.types[:like]).returns(false)
    xhr :get, :index, id: post.id, post_action_type_id: PostActionType.types[:like]
    expect(response).to be_forbidden
  end

  it 'succeeds' do
    xhr :get, :index, id: post.id, post_action_type_id: PostActionType.types[:like]
    expect(response).to be_success
  end
end
