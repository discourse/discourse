# frozen_string_literal: true

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

  it 'cant trivially resolve conflicts without interaction' do

    user = sign_in(Fabricate(:user))

    DraftSequence.next!(user, "abc")

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: 0,
      data: { a: "test" }.to_json,
      owner: "abcdefg"
    }

    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json["draft_sequence"]).to eq(1)
  end

  it 'has a clean protocol for ownership handover' do
    user = sign_in(Fabricate(:user))

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: 0,
      data: { a: "test" }.to_json,
      owner: "abcdefg"
    }

    expect(response.status).to eq(200)

    json = JSON.parse(response.body)
    expect(json["draft_sequence"]).to eq(0)

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: 0,
      data: { b: "test" }.to_json,
      owner: "hijklmnop"
    }

    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json["draft_sequence"]).to eq(1)

    expect(DraftSequence.current(user, "abc")).to eq(1)

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: 1,
      data: { c: "test" }.to_json,
      owner: "hijklmnop"
    }

    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json["draft_sequence"]).to eq(1)

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: 1,
      data: { c: "test" }.to_json,
      owner: "abc"
    }

    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json["draft_sequence"]).to eq(2)
  end

  it 'raises an error for out-of-sequence draft setting' do

    user = sign_in(Fabricate(:user))
    seq = DraftSequence.next!(user, "abc")
    Draft.set(user, "abc", seq, { b: "test" }.to_json)

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: seq - 1,
      data: { a: "test" }.to_json
    }

    expect(response.status).to eq(409)

    post "/draft.json", params: {
      draft_key: "abc",
      sequence: seq + 1,
      data: { a: "test" }.to_json
    }

    expect(response.status).to eq(409)

  end
end
