require 'rails_helper'
require_dependency 'queued_posts_controller'

# NOTE: This controller only exists for backwards compatibility
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
    let(:qp) { Fabricate(:reviewable_queued_post) }

    context 'not found' do
      it 'returns json error' do
        qp.destroy!

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'approved' }
        }

        expect(response.status).to eq(404)
      end
    end

    context 'approved' do
      it 'updates the post to approved' do

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'approved' }
        }

        expect(response.status).to eq(200)
        json = ::JSON.parse(response.body)
        qp_json = json['queued_posts']

        expect(qp_json['state']).to eq(2)
      end
    end

    context 'rejected' do
      it 'updates the post to rejected' do

        put "/queued_posts/#{qp.id}.json", params: {
          queued_post: { state: 'rejected' }
        }

        expect(response.status).to eq(200)

        json = ::JSON.parse(response.body)
        qp_json = json['queued_posts']
        expect(qp_json['state']).to eq(3)
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
        let(:queued_topic) { Fabricate(:reviewable_queued_post_topic,) }

        it 'updates the topic attributes' do
          put "/queued_posts/#{queued_topic.id}.json", params: {
            queued_post: changes
          }

          expect(response.status).to eq(200)
          queued_topic.reload

          expect(queued_topic.payload['raw']).to eq(changes[:raw])
          expect(queued_topic.payload['title']).to eq(changes[:title])
          expect(queued_topic.category_id).to eq(changes[:category_id])
          expect(queued_topic.payload['tags']).to eq(changes[:tags])
        end

        it 'removes tags if not present' do
          queued_topic.payload[:tags] = ['another-tag']
          queued_topic.save!

          put "/queued_posts/#{queued_topic.id}.json", params: {
            queued_post: changes.except(:tags)
          }

          expect(response.status).to eq(200)
          queued_topic.reload

          expect(queued_topic.payload['raw']).to eq(changes[:raw])
          expect(queued_topic.payload['title']).to eq(changes[:title])
          expect(queued_topic.category_id).to eq(changes[:category_id])
          expect(queued_topic.payload['tags']).to be_nil
        end
      end

      context 'when it is a reply' do
        let(:queued_reply) { Fabricate(:reviewable_queued_post) }

        it 'updates the reply attributes' do
          put "/queued_posts/#{queued_reply.id}.json", params: {
            queued_post: changes
          }

          original_category = queued_reply.category_id
          expect(response.status).to eq(200)
          queued_reply.reload

          expect(queued_reply.payload['raw']).to eq(changes[:raw])
          expect(queued_reply.payload['title']).to be_nil
          expect(queued_reply.category_id).to eq(original_category)
          expect(queued_reply.payload['tags']).to be_nil
        end
      end
    end
  end
end
