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
          tags: ['new_tag']
        }
      end

      context 'when it is a topic' do
        let(:queued_topic) { Fabricate(:queued_topic) }

        before do
          put :update, params: {
            id: queued_topic.id, queued_post: changes
          }, format: :json

          expect(response).to be_success
        end

        it 'updates raw' do
          expect(queued_topic.reload.raw).to eq(changes[:raw])
        end

        it 'updates the title' do
          expect(queued_topic.reload.post_options['title']).to eq(changes[:title])
        end

        it 'updates the category' do
          expect(queued_topic.reload.post_options['category']).to eq(changes[:category_id])
        end

        it 'updates the tags' do
          expect(queued_topic.reload.post_options['tags']).to eq(changes[:tags])
        end
      end

      context 'when it is a reply' do
        let(:queued_reply) { Fabricate(:queued_post) }

        before do
          put :update, params: {
            id: queued_reply.id, queued_post: changes
          }, format: :json

          expect(response).to be_success
        end

        it 'updates raw' do
          expect(queued_reply.reload.raw).to eq(changes[:raw])
        end

        it 'does not update the title' do
          expect(queued_reply.reload.post_options['title']).to be_nil
        end

        it 'does not update the category' do
          original_category = queued_reply.post_options['category']
          expect(queued_reply.reload.post_options['category']).to eq(original_category)
        end

        it 'does not update the tags' do
          expect(queued_reply.reload.post_options['tags']).to be_nil
        end
      end
    end
  end
end
