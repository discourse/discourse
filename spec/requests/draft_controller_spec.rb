require 'rails_helper'

describe DraftController do
  it 'requires you to be logged in' do
    post "/draft"
    expect(response.status).to eq(403)
  end

  it 'saves a draft on update' do
    user = sign_in(Fabricate(:user))
    post "/draft.json", params: { draft_key: 'xyz', data: 'my data', sequence: 0 }
    expect(response.status).to eq(200)
    expect(Draft.get(user, 'xyz', 0)).to eq('my data')
  end

  it 'destroys drafts when required' do
    user = sign_in(Fabricate(:user))
    Draft.set(user, 'xxx', 0, 'hi')
    delete "/draft.json", params: { draft_key: 'xxx', sequence: 0 }
    expect(response.status).to eq(200)
    expect(Draft.get(user, 'xxx', 0)).to eq(nil)
  end
end
