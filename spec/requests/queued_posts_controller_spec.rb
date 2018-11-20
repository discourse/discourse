require 'rails_helper'
require_dependency 'queued_posts_controller'
require_dependency 'queued_post'

describe QueuedPostsController do
  context 'without authentication' do
    it 'fails' do
      get "/queued-posts.json"
      expect(response).to be_forbidden
    end
  end

  context 'as a regular user' do
    before { sign_in(Fabricate(:user)) }

    it 'fails' do
      get "/queued-posts.json"
      expect(response).to be_forbidden
    end
  end

  context 'as an admin' do
    before { sign_in(Fabricate(:moderator)) }

    it 'returns the queued posts' do
      get "/queued-posts.json"
      expect(response.status).to eq(200)
    end
  end

  describe '#update' do
    before { sign_in(Fabricate(:moderator)) }
    let(:qp) { Fabricate(:queued_post) }

    context 'not found' do
      it 'returns json error' do
        qp.destroy!

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'approved' }
        }

        expect(response.status).to eq(422)

        expect(JSON.parse(response.body)["errors"].first).to eq(I18n.t('queue.not_found'))
      end
    end

    context 'approved' do
      it 'updates the post to approved' do

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'approved' }
        }

        expect(response.status).to eq(200)

        qp.reload
        expect(qp.state).to eq(QueuedPost.states[:approved])
      end
    end

    context 'rejected' do
      it 'updates the post to rejected' do

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'rejected' }
        }

        expect(response.status).to eq(200)

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

        it 'updates the topic attributes' do
          put "/queued_posts/#{queued_topic.id}.json", params: {
            queued_post: changes
          }

          expect(response.status).to eq(200)
          queued_topic.reload

          expect(queued_topic.raw).to eq(changes[:raw])
          expect(queued_topic.post_options['title']).to eq(changes[:title])
          expect(queued_topic.post_options['category']).to eq(changes[:category_id])
          expect(queued_topic.post_options['tags']).to eq(changes[:tags])
        end

        it 'removes tags if not present' do
          queued_topic.post_options[:tags] = ['another-tag']
          queued_topic.save!

          put "/queued_posts/#{queued_topic.id}.json", params: {
            queued_post: changes.except(:tags)
          }

          expect(response.status).to eq(200)
          queued_topic.reload

          expect(queued_topic.raw).to eq(changes[:raw])
          expect(queued_topic.post_options['title']).to eq(changes[:title])
          expect(queued_topic.post_options['category']).to eq(changes[:category_id])
          expect(queued_topic.post_options['tags']).to be_nil
        end
      end

      context 'when it is a reply' do
        let(:queued_reply) { Fabricate(:queued_post) }

        it 'updates the reply attributes' do
          put "/queued_posts/#{queued_reply.id}.json", params: {
            queued_post: changes
          }

          original_category = queued_reply.post_options['category']
          expect(response.status).to eq(200)
          queued_reply.reload

          expect(queued_reply.raw).to eq(changes[:raw])
          expect(queued_reply.post_options['title']).to be_nil
          expect(queued_reply.post_options['category']).to eq(original_category)
          expect(queued_reply.post_options['tags']).to be_nil
        end
      end
    end
  end
end
