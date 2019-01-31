require 'rails_helper'

describe DraftController do
  it 'requires you to be logged in' do
    post "/draft"
    expect(response.status).to eq(403)
  end

  it 'saves a draft on update' do
    user = sign_in(Fabricate(:user))

    post "/draft.json", params: {
      draft_key: 'xyz',
      data: { my: "data" }.to_json,
      sequence: 0
    }

    expect(response.status).to eq(200)
    expect(Draft.get(user, 'xyz', 0)).to eq(%q({"my":"data"}))
  end

  it 'checks for an conflict on update' do
    user = sign_in(Fabricate(:user))
    post = Fabricate(:post, user: user)

    post "/draft.json", params: {
      username: user.username,
      draft_key: "topic",
      sequence: 0,
      data: {
        postId: post.id,
        originalText: post.raw,
        action: "edit"
      }.to_json
    }

    expect(JSON.parse(response.body)['conflict_user']).to eq(nil)

    post "/draft.json", params: {
      username: user.username,
      draft_key: "topic",
      sequence: 0,
      data: {
        postId: post.id,
        originalText: "something else",
        action: "edit"
      }.to_json
    }

    json = JSON.parse(response.body)

    expect(json['conflict_user']['id']).to eq(post.last_editor.id)
    expect(json['conflict_user']).to include('avatar_template')
  end

  it 'destroys drafts when required' do
    user = sign_in(Fabricate(:user))
    Draft.set(user, 'xxx', 0, 'hi')
    delete "/draft.json", params: { draft_key: 'xxx', sequence: 0 }
    expect(response.status).to eq(200)
    expect(Draft.get(user, 'xxx', 0)).to eq(nil)
  end
end
