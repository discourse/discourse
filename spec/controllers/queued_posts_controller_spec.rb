require 'rails_helper'
require_dependency 'queued_posts_controller'
require_dependency 'queued_post'

describe QueuedPostsController do
  context 'without authentication' do
    it 'fails' do
      get :index, format: :json
      expect(response).not_to be_success
    end
  end

  context 'as a regular user' do
    let!(:user) { log_in(:user) }
    it 'fails' do
      get :index, format: :json
      expect(response).not_to be_success
    end
  end

  context 'as an admin' do
    let!(:user) { log_in(:moderator) }

    it 'returns the queued posts' do
      get :index, format: :json
      expect(response).to be_success
    end
  end

  describe '#update' do
    let!(:user) { log_in(:moderator) }
    let(:qp) { Fabricate(:queued_post) }

    context 'not found' do
      it 'returns json error' do
        qp.destroy!

        put :update, params: {
          id: qp.id, queued_post: { state: 'approved' }
        }, format: :json

        expect(response.status).to eq(422)

        expect(eval(response.body)).to eq(described_class.new.create_errors_json(I18n.t('queue.not_found')))
      end
    end

    context 'approved' do
      it 'updates the post to approved' do

        put :update, params: {
          id: qp.id, queued_post: { state: 'approved' }
        }, format: :json

        expect(response).to be_success

        qp.reload
        expect(qp.state).to eq(QueuedPost.states[:approved])
      end
    end

    context 'rejected' do
      it 'updates the post to rejected' do

        put :update, params: {
          id: qp.id, queued_post: { state: 'rejected' }
        }, format: :json

        expect(response).to be_success

        qp.reload
        expect(qp.state).to eq(QueuedPost.states[:rejected])
      end
    end

    context 'editing content' do
      let(:changes) do
        {
          raw: 'new raw',
          title: 'new title',
          category_id: 10,
          tags: ['new_tag'],
          edit_reason: 'keep everything up to date'
        }
      end

      context 'when it is a topic' do
        let(:queued_topic) { Fabricate(:queued_topic) }

        before do
          put :update, params: {
            id: queued_topic.id, queued_post: changes
          }, format: :json
        end

        it { is_expected.to respond_with :success }

        it 'save the changes to post_options[:changes]' do
          queued_topic.reload

          expect(queued_topic.post_options['changes']['raw']).to eq(changes[:raw])
          expect(queued_topic.post_options['changes']['title']).to eq(changes[:title])
          expect(queued_topic.post_options['changes']['category_id']).to eq(changes[:category_id])
          expect(queued_topic.post_options['changes']['tags']).to eq(changes[:tags])
        end

        it 'does not affect the original post data' do
          original_post = queued_topic.dup

          queued_topic.reload

          expect(queued_topic.raw).to eq(original_post.raw)
          expect(queued_topic.post_options['title']).to eq(original_post.post_options['title'])
          expect(queued_topic.post_options['category']).to eq(original_post.post_options['category'])
          expect(queued_topic.post_options['tags']).to eq(original_post.post_options['tags'])
        end

        it 'records editor_id and edit_reason' do
          queued_topic.reload

          expect(queued_topic.post_options['changes']['editor_id']).to eq(user.id)
          expect(queued_topic.post_options['changes']['edit_reason']).to eq(changes[:edit_reason])
        end
      end

      context 'when it is a reply' do
        let(:queued_reply) { Fabricate(:queued_post) }

        before do
          put :update, params: {
            id: queued_reply.id, queued_post: changes
          }, format: :json
        end

        it { is_expected.to respond_with :success }

        it 'updates raw' do
          original_raw = queued_reply.raw

          queued_reply.reload

          expect(queued_reply.raw).to eq(original_raw)
          expect(queued_reply.post_options['changes']['raw']).to eq(changes[:raw])
        end

        it 'save the changes to post_options[:changes]' do
          queued_reply.reload

          expect(queued_reply.post_options['changes']['raw']).to eq(changes[:raw])
          expect(queued_reply.post_options['changes']['title']).to be_nil, "title cannot be edited for a reply"
          expect(queued_reply.post_options['changes']['category_id']).to be_nil, "category cannot be edited for a reply"
          expect(queued_reply.post_options['changes']['tags']).to be_nil, "tags cannot be edited for a reply"
        end

        it 'does not affect the original post data' do
          original_post = queued_reply.dup

          queued_reply.reload

          expect(queued_reply.raw).to eq(original_post.raw)
          expect(queued_reply.post_options['title']).to eq(original_post.post_options['title'])
          expect(queued_reply.post_options['category']).to eq(original_post.post_options['category'])
          expect(queued_reply.post_options['tags']).to eq(original_post.post_options['tags'])
        end

        it 'records editor_id and edit_reason' do
          queued_reply.reload

          expect(queued_reply.post_options['changes']['editor_id']).to eq(user.id)
          expect(queued_reply.post_options['changes']['edit_reason']).to eq(changes[:edit_reason])
        end
      end
    end
  end
end
