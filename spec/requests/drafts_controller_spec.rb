# frozen_string_literal: true

require 'rails_helper'

describe DraftsController do
  it 'requires you to be logged in' do
    get "/drafts.json"
    expect(response.status).to eq(403)
  end

  it 'returns correct stream length after adding a draft' do
    user = sign_in(Fabricate(:user))
    Draft.set(user, 'xxx', 0, '{}')
    get "/drafts.json", params: { username: user.username }
    expect(response.status).to eq(200)
    parsed = response.parsed_body
    expect(parsed["drafts"].length).to eq(1)
  end

  it 'has empty stream after deleting last draft' do
    user = sign_in(Fabricate(:user))
    Draft.set(user, 'xxx', 0, '{}')
    Draft.clear(user, 'xxx', 0)
    get "/drafts.json", params: { username: user.username }
    expect(response.status).to eq(200)
    parsed = response.parsed_body
    expect(parsed["drafts"].length).to eq(0)
  end

  it 'does not let a user see drafts stream of another user' do
    user_b = Fabricate(:user)
    Draft.set(user_b, 'xxx', 0, '{}')
    sign_in(Fabricate(:user))
    get "/drafts.json", params: { username: user_b.username }
    expect(response.status).to eq(403)
  end

  it 'does not include topic details when user cannot see topic' do
    topic = Fabricate(:private_message_topic)
    topic_user = topic.user
    other_user = Fabricate(:user)
    Draft.set(topic_user, "topic_#{topic.id}", 0, '{}')
    Draft.set(other_user, "topic_#{topic.id}", 0, '{}')

    sign_in(topic_user)
    get "/drafts.json", params: { username: topic_user.username }
    expect(response.status).to eq(200)
    parsed = response.parsed_body
    expect(parsed["drafts"].first["title"]).to eq(topic.title)

    sign_in(other_user)
    get "/drafts.json", params: { username: other_user.username }
    expect(response.status).to eq(200)
    parsed = response.parsed_body
    expect(parsed["drafts"].first["title"]).to eq(nil)
  end
end
