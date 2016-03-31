require 'rails_helper'
require_dependency 'queued_posts_controller'
require_dependency 'queued_post'

describe QueuedPostsController do
  context 'without authentication' do
    it 'fails' do
      xhr :get, :index
      expect(response).not_to be_success
    end
  end

  context 'as a regular user' do
    let!(:user) { log_in(:user) }
    it 'fails' do
      xhr :get, :index
      expect(response).not_to be_success
    end
  end

  context 'as an admin' do
    let!(:user) { log_in(:moderator) }

    it 'returns the queued posts' do
      xhr :get, :index
      expect(response).to be_success
    end
  end


  context 'update' do
    let!(:user) { log_in(:moderator) }
    let(:qp) { Fabricate(:queued_post) }

    context 'approved' do
      it 'updates the post to approved' do

        xhr :put, :update, id: qp.id, queued_post: { state: 'approved' }
        expect(response).to be_success

        qp.reload
        expect(qp.state).to eq(QueuedPost.states[:approved])
      end
    end

    context 'rejected' do
      it 'updates the post to approved' do

        xhr :put, :update, id: qp.id, queued_post: { state: 'rejected' }
        expect(response).to be_success

        qp.reload
        expect(qp.state).to eq(QueuedPost.states[:rejected])
      end
    end

  end
end

