require 'rails_helper'

RSpec.describe PostActionsController do
  describe '#destroy' do
    let(:post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    it 'requires you to be logged in' do
      delete '/post_action.json', params: { id: post.id }
      expect(response.status).to eq(404)
    end
  end

  describe '#create' do

    it 'requires you to be logged in' do
      post '/post_actions.json'
      expect(response.status).to eq(403)
    end

    describe 'as a moderator' do
      let(:user) { Fabricate(:moderator) }
      let(:post_1) { Fabricate(:post, user: Fabricate(:coding_horror)) }

      before do
        sign_in(user)
      end

      it 'raises an error when the id is missing' do
        post "/post_actions.json", params: {
          post_action_type_id: PostActionType.types[:like]
        }
        expect(response.status).to eq(400)
      end

      it 'fails when the id is invalid' do
        post "/post_actions.json", params: {
          post_action_type_id: PostActionType.types[:like], id: -1
        }

        expect(response.status).to eq(404)
      end

      it 'raises an error when the post_action_type_id index is missing' do
        post "/post_actions.json", params: { id: post_1.id }
        expect(response.status).to eq(400)
      end

      it "fails when the user doesn't have permission to see the post" do
        post_1 = Fabricate(:private_message_post, user: Fabricate(:user))

        post "/post_actions.json", params: {
          id: post_1.id, post_action_type_id: PostActionType.types[:like]
        }

        expect(response).to be_forbidden
      end

      it 'allows us to create an post action on a post' do
        expect do
          post "/post_actions.json", params: {
            id: post_1.id, post_action_type_id: PostActionType.types[:like]
          }
        end.to change { PostAction.count }.by(1)

        post_action = PostAction.last

        expect(post_action.post_id).to eq(post_1.id)
        expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
      end

      it "passes a list of taken actions through" do
        PostAction.create(
          post_id: post_1.id,
          user_id: user.id,
          post_action_type_id: PostActionType.types[:inappropriate]
        )

        post "/post_actions.json", params: {
          id: post_1.id, post_action_type_id: PostActionType.types[:off_topic]
        }

        expect(response).to_not be_success
      end

      it 'passes the message through' do
        message = 'action message goes here'

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:notify_user],
          message: message
        }

        expect(PostAction.last.post_id).to eq(post_1.id)
        expect(Post.last.raw).to include(message)
      end

      it 'passes the message through as warning' do
        message = 'action message goes here'

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:notify_user],
          message: message,
          is_warning: true
        }

        expect(PostAction.last.post_id).to eq(post_1.id)

        post = Post.last

        expect(post.raw).to include(message)
        expect(post.topic.is_official_warning?).to eq(true)
      end

      it "doesn't create message as a warning if the user isn't staff" do
        sign_in(Fabricate(:user))

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:notify_user],
          message: 'action message goes here',
          is_warning: true
        }

        expect(response.status).to eq(403)
      end

      it 'passes take_action through' do
        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:spam],
          take_action: 'true'
        }

        expect(response).to be_success

        post_action = PostAction.last

        expect(post_action.post_id).to eq(post_1.id)
        expect(post_action.staff_took_action).to eq(true)
      end

      it "doesn't pass take_action through if the user isn't staff" do
        sign_in(Fabricate(:user))

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:like]
        }

        expect(response).to be_success

        post_action = PostAction.last

        expect(post_action.post_id).to eq(post_1.id)
        expect(post_action.staff_took_action).to eq(false)
      end
    end
  end
end
