# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostActionsController do
  describe '#destroy' do
    fab!(:post) { Fabricate(:post, user: Fabricate(:coding_horror)) }

    it 'requires you to be logged in' do
      delete "/post_actions/#{post.id}.json"
      expect(response.status).to eq(403)
    end

    context 'logged in' do
      fab!(:user) { Fabricate(:user) }

      before do
        sign_in(user)
      end

      it 'raises an error when the post_action_type_id is missing' do
        delete "/post_actions/#{post.id}.json"
        expect(response.status).to eq(400)
      end

      it "returns 404 when the post action type doesn't exist for that user" do
        delete "/post_actions/#{post.id}.json", params: { post_action_type_id: PostActionType.types[:bookmark] }
        expect(response.status).to eq(404)
      end

      context 'with a post_action record ' do
        let!(:post_action) do
          PostAction.create!(
            user_id: user.id,
            post_id: post.id,
            post_action_type_id: PostActionType.types[:bookmark]
          )
        end

        it 'returns success' do
          delete "/post_actions/#{post.id}.json", params: { post_action_type_id: PostActionType.types[:bookmark] }
          expect(response.status).to eq(200)
        end

        it 'deletes the action' do
          delete "/post_actions/#{post.id}.json", params: {
            post_action_type_id: PostActionType.types[:bookmark]
          }

          expect(response.status).to eq(200)
          expect(PostAction.exists?(
            user_id: user.id,
            post_id: post.id,
            post_action_type_id: PostActionType.types[:bookmark],
            deleted_at: nil
          )).to eq(false)
        end

        it "isn't deleted when the user doesn't have permission" do
          pa = PostAction.create!(
            post: post,
            user: user,
            post_action_type_id: PostActionType.types[:like],
            created_at: 1.day.ago
          )

          delete "/post_actions/#{post.id}.json", params: {
            post_action_type_id: PostActionType.types[:like]
          }

          expect(response).to be_forbidden
        end
      end
    end
  end

  describe '#create' do
    it 'requires you to be logged in' do
      post '/post_actions.json'
      expect(response.status).to eq(403)
    end

    it 'fails when the user does not have permission to see the post' do
      sign_in(Fabricate(:user))
      pm = Fabricate(:private_message_post, user: Fabricate(:coding_horror))

      post "/post_actions.json", params: {
        id: pm.id,
        post_action_type_id: PostActionType.types[:bookmark]
      }

      expect(response.status).to eq(403)
    end

    it 'fails when the user tries to notify user that has disabled PM' do
      sign_in(Fabricate(:user))
      user2 = Fabricate(:user)

      post = Fabricate(:post, user: user2)
      user2.user_option.update!(allow_private_messages: false)

      post "/post_actions.json", params: {
        id: post.id,
        post_action_type_id: PostActionType.types[:notify_user],
        message: 'testing',
        flag_topic: false
      }

      expect(response.status).to eq(422)

      expect(JSON.parse(response.body)["errors"].first).to eq(I18n.t(
        :not_accepting_pms, username: user2.username
      ))
    end

    describe 'as a moderator' do
      fab!(:user) { Fabricate(:moderator) }
      fab!(:post_1) { Fabricate(:post, user: Fabricate(:coding_horror)) }

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

        expect(response.status).to eq(200)
        expect(post_action.post_id).to eq(post_1.id)
        expect(post_action.post_action_type_id).to eq(PostActionType.types[:like])
      end

      it "passes a list of taken actions through" do
        PostAction.create!(
          post_id: post_1.id,
          user_id: user.id,
          post_action_type_id: PostActionType.types[:inappropriate]
        )

        post "/post_actions.json", params: {
          id: post_1.id, post_action_type_id: PostActionType.types[:off_topic]
        }

        expect(response).to be_forbidden
      end

      it 'passes the message through' do
        message = 'action message goes here'

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:notify_user],
          message: message
        }

        expect(response.status).to eq(200)
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

        expect(response.status).to eq(200)
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

        expect(response.status).to eq(200)

        post_action = PostAction.find_by(post: post_1)
        expect(post_action.staff_took_action).to eq(true)

        reviewable = ReviewableFlaggedPost.find_by(target: post_1)
        score = reviewable.reviewable_scores.first
        expect(score.took_action?).to eq(true)
      end

      it "doesn't pass take_action through if the user isn't staff" do
        sign_in(Fabricate(:user))

        post "/post_actions.json", params: {
          id: post_1.id,
          post_action_type_id: PostActionType.types[:inappropriate]
        }

        expect(response.status).to eq(200)

        post_action = PostAction.find_by(post: post_1)
        expect(post_action.staff_took_action).to eq(false)

        reviewable = ReviewableFlaggedPost.find_by(target: post_1)
        score = reviewable.reviewable_scores.first
        expect(score.took_action?).to eq(false)
      end
    end
  end

end
