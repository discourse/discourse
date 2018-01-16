require 'rails_helper'

describe DraftController do

  it 'requires you to be logged in' do
    post :update
    expect(response.status).to eq(403)
  end

  it 'saves a draft on update' do
    user = log_in
    post :update, params: { draft_key: 'xyz', data: 'my data', sequence: 0 }, format: :json
    expect(Draft.get(user, 'xyz', 0)).to eq('my data')
  end

  it 'destroys drafts when required' do
    user = log_in
    Draft.set(user, 'xxx', 0, 'hi')
    delete :destroy, params: { draft_key: 'xxx', sequence: 0 }, format: :json
    expect(Draft.get(user, 'xxx', 0)).to eq(nil)
  end

end
