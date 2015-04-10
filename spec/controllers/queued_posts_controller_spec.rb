require 'spec_helper'

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
end

