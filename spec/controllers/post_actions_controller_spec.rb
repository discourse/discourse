require 'rails_helper'

describe PostActionsController do

  describe 'create' do

    context 'logged in as user' do
      let(:user) { Fabricate(:user) }
      let(:private_message) { Fabricate(:private_message_post, user: Fabricate(:coding_horror)) }

      before do
        log_in_user(user)
      end

      it 'fails when the user does not have permission to see the post' do
        post :create, params: {
          id: private_message.id,
          post_action_type_id: PostActionType.types[:bookmark]
        }, format: :json

        expect(response).to be_forbidden
      end
    end
  end

  context 'destroy' do

    let(:post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    context 'logged in' do
      let!(:user) { log_in }

      it 'raises an error when the post_action_type_id is missing' do
        expect do
          delete :destroy, params: { id: post.id }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "returns 404 when the post action type doesn't exist for that user" do
        delete :destroy, params: { id: post.id, post_action_type_id: 1 }, format: :json
        expect(response.code).to eq('404')
      end

      context 'with a post_action record ' do
        let!(:post_action) { PostAction.create(user_id: user.id, post_id: post.id, post_action_type_id: 1) }

        it 'returns success' do
          delete :destroy, params: { id: post.id, post_action_type_id: 1 }, format: :json
          expect(response).to be_success
        end

        it 'deletes the action' do
          delete :destroy, params: {
            id: post.id, post_action_type_id: 1
          }, format: :json

          expect(PostAction.exists?(user_id: user.id, post_id: post.id, post_action_type_id: 1, deleted_at: nil)).to eq(false)
        end

        it 'ensures it can be deleted' do
          Guardian.any_instance.expects(:can_delete?).with(post_action).returns(false)

          delete :destroy, params: {
            id: post.id, post_action_type_id: 1
          }, format: :json

          expect(response).to be_forbidden
        end
      end

    end

  end

  context 'defer_flags' do

    let(:flagged_post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    context "not logged in" do
      it "should not allow them to clear flags" do
        post :defer_flags, format: :json
        expect(response.status).to eq(403)
      end
    end

    context 'logged in' do
      let!(:user) { log_in(:moderator) }

      it "raises an error without a post_action_type_id" do
        expect do
          post :defer_flags, params: { id: flagged_post.id }, format: :json
        end.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have access" do
        Guardian.any_instance.expects(:can_defer_flags?).returns(false)

        post :defer_flags, params: {
          id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
        }, format: :json

        expect(response).to be_forbidden
      end

      context "success" do
        before do
          Guardian.any_instance.expects(:can_defer_flags?).returns(true)
          PostAction.expects(:defer_flags!).with(flagged_post, user)
        end

        it "delegates to defer_flags" do
          post :defer_flags, params: {
            id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
          }, format: :json

          expect(response).to be_success
        end

        it "works with a deleted post" do
          flagged_post.trash!(user)

          post :defer_flags, params: {
            id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
          }, format: :json

          expect(response).to be_success
        end

      end

    end

  end

end
