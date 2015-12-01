require 'rails_helper'

describe DraftController do

  it 'requires you to be logged in' do
    expect { post :update }.to raise_error(Discourse::NotLoggedIn)
  end

  it 'saves a draft on update' do
    user = log_in
    post :update, draft_key: 'xyz', data: 'my data', sequence: 0
    expect(Draft.get(user, 'xyz', 0)).to eq('my data')
  end

  it 'destroys drafts when required' do
    user = log_in
    Draft.set(user, 'xxx', 0, 'hi')
    delete :destroy, draft_key: 'xxx', sequence: 0
    expect(Draft.get(user, 'xxx', 0)).to eq(nil)
  end

end
