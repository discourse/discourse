require 'rails_helper'

describe PostActionsController do

  describe 'create' do
    it 'requires you to be logged in' do
      expect { xhr :post, :create }.to raise_error(Discourse::NotLoggedIn)
    end

    describe 'logged in as moderator' do
      before do
        @user = log_in(:moderator)
        @post = Fabricate(:post, user: Fabricate(:coding_horror))
      end

      it 'raises an error when the id is missing' do
        expect { xhr :post, :create, post_action_type_id: PostActionType.types[:like] }.to raise_error(ActionController::ParameterMissing)
      end

      it 'raises an error when the post_action_type_id index is missing' do
        expect { xhr :post, :create, id: @post.id }.to raise_error(ActionController::ParameterMissing)
      end

      it "fails when the user doesn't have permission to see the post" do
        Guardian.any_instance.expects(:can_see?).with(@post).returns(false)
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like]
        expect(response).to be_forbidden
      end

      it "fails when the user doesn't have permission to perform that action" do
        Guardian.any_instance.expects(:post_can_act?).with(@post, :like, taken_actions: nil).returns(false)
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like]
        expect(response).to be_forbidden
      end

      it 'allows us to create an post action on a post' do
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like]
      end

      it "passes a list of taken actions through" do
        PostAction.create(post_id: @post.id, user_id: @user.id, post_action_type_id: PostActionType.types[:inappropriate])
        Guardian.any_instance.expects(:post_can_act?).with(@post, :off_topic, has_entry({:taken_actions => has_key(PostActionType.types[:inappropriate])}))
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:off_topic]
      end

      it 'passes the message through' do
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {message: 'action message goes here'})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like], message: 'action message goes here'
      end

      it 'passes the message through as warning' do
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {message: 'action message goes here', is_warning: true})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like], message: 'action message goes here', is_warning: true
      end

      it "doesn't create message as a warning if the user isn't staff" do
        Guardian.any_instance.stubs(:is_staff?).returns(false)
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {message: 'action message goes here'})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like], message: 'action message goes here', is_warning: true
      end

      it 'passes take_action through' do
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {take_action: true})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like], take_action: 'true'
      end

      it "doesn't pass take_action through if the user isn't staff" do
        Guardian.any_instance.stubs(:is_staff?).returns(false)
        PostAction.expects(:act).once.with(@user, @post, PostActionType.types[:like], {})
        xhr :post, :create, id: @post.id, post_action_type_id: PostActionType.types[:like], take_action: 'true'
      end

    end

  end

  context 'destroy' do

    let(:post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    it 'requires you to be logged in' do
      expect { xhr :delete, :destroy, id: post.id }.to raise_error(Discourse::NotLoggedIn)
    end

    context 'logged in' do
      let!(:user) { log_in }

      it 'raises an error when the post_action_type_id is missing' do
        expect { xhr :delete, :destroy, id: post.id }.to raise_error(ActionController::ParameterMissing)
      end

      it "returns 404 when the post action type doesn't exist for that user" do
        xhr :delete, :destroy, id: post.id, post_action_type_id: 1
        expect(response.code).to eq('404')
      end

      context 'with a post_action record ' do
        let!(:post_action) { PostAction.create(user_id: user.id, post_id: post.id, post_action_type_id: 1)}

        it 'returns success' do
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          expect(response).to be_success
        end

        it 'deletes the action' do
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          expect(PostAction.exists?(user_id: user.id, post_id: post.id, post_action_type_id: 1, deleted_at: nil)).to eq(false)
        end

        it 'ensures it can be deleted' do
          Guardian.any_instance.expects(:can_delete?).with(post_action).returns(false)
          xhr :delete, :destroy, id: post.id, post_action_type_id: 1
          expect(response).to be_forbidden
        end
      end

    end

  end

  context 'defer_flags' do

    let(:flagged_post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    context "not logged in" do
      it "should not allow them to clear flags" do
        expect { xhr :post, :defer_flags }.to raise_error(Discourse::NotLoggedIn)
      end
    end

    context 'logged in' do
      let!(:user) { log_in(:moderator) }

      it "raises an error without a post_action_type_id" do
        expect { xhr :post, :defer_flags, id: flagged_post.id }.to raise_error(ActionController::ParameterMissing)
      end

      it "raises an error when the user doesn't have access" do
        Guardian.any_instance.expects(:can_defer_flags?).returns(false)
        xhr :post, :defer_flags, id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
        expect(response).to be_forbidden
      end

      context "success" do
        before do
          Guardian.any_instance.expects(:can_defer_flags?).returns(true)
          PostAction.expects(:defer_flags!).with(flagged_post, user)
        end

        it "delegates to defer_flags" do
          xhr :post, :defer_flags, id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
          expect(response).to be_success
        end

        it "works with a deleted post" do
          flagged_post.trash!(user)
          xhr :post, :defer_flags, id: flagged_post.id, post_action_type_id: PostActionType.types[:spam]
          expect(response).to be_success
        end

      end

    end

  end

end
