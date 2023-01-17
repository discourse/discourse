# frozen_string_literal: true

require 'rails_helper'

describe DraftsController do
  describe "#index" do
    it 'requires you to be logged in' do
      get "/drafts.json"
      expect(response.status).to eq(403)
    end

    it 'returns correct stream length after adding a draft' do
      user = sign_in(Fabricate(:user))
      Draft.set(user, 'xxx', 0, '{}')
      get "/drafts.json"
      expect(response.status).to eq(200)
      parsed = response.parsed_body
      expect(response.parsed_body["drafts"].length).to eq(1)
    end

    it 'has empty stream after deleting last draft' do
      user = sign_in(Fabricate(:user))
      Draft.set(user, 'xxx', 0, '{}')
      Draft.clear(user, 'xxx', 0)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].length).to eq(0)
    end

    it 'does not include topic details when user cannot see topic' do
      topic = Fabricate(:private_message_topic)
      topic_user = topic.user
      other_user = Fabricate(:user)
      Draft.set(topic_user, "topic_#{topic.id}", 0, '{}')
      Draft.set(other_user, "topic_#{topic.id}", 0, '{}')

      sign_in(topic_user)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].first["title"]).to eq(topic.title)

      sign_in(other_user)
      get "/drafts.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["drafts"].first["title"]).to eq(nil)
    end
  end

  describe "#show" do
    it "returns a draft if requested" do
      user = sign_in(Fabricate(:user))
      Draft.set(user, 'hello', 0, 'test')

      get "/drafts/hello.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body['draft']).to eq('test')
    end
  end

  describe "#create" do
    it 'requires you to be logged in' do
      post "/drafts.json"
      expect(response.status).to eq(403)
    end

    it 'saves a draft' do
      user = sign_in(Fabricate(:user))

      post "/drafts.json", params: {
        draft_key: 'xyz',
        data: { my: "data" }.to_json,
        sequence: 0
      }

      expect(response.status).to eq(200)
      expect(Draft.get(user, 'xyz', 0)).to eq(%q({"my":"data"}))
    end

    it "returns 404 when the key is missing" do
      sign_in(Fabricate(:user))
      post "/drafts.json", params: { data: { my: "data" }.to_json, sequence: 0 }
      expect(response.status).to eq(404)
    end

    it 'checks for an conflict on update' do
      user = sign_in(Fabricate(:user))
      post = Fabricate(:post, user: user)

      post "/drafts.json", params: {
        draft_key: "topic",
        sequence: 0,
        data: {
          postId: post.id,
          originalText: post.raw,
          action: "edit"
        }.to_json
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body['conflict_user']).to eq(nil)

      post "/drafts.json", params: {
        draft_key: "topic",
        sequence: 0,
        data: {
          postId: post.id,
          originalText: "something else",
          action: "edit"
        }.to_json
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body['conflict_user']['id']).to eq(post.last_editor.id)
      expect(response.parsed_body['conflict_user']).to include('avatar_template')
    end

    it 'cant trivially resolve conflicts without interaction' do

      user = sign_in(Fabricate(:user))

      DraftSequence.next!(user, "abc")

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: 0,
        data: { a: "test" }.to_json,
        owner: "abcdefg"
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(1)
    end

    it 'has a clean protocol for ownership handover' do
      user = sign_in(Fabricate(:user))

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: 0,
        data: { a: "test" }.to_json,
        owner: "abcdefg"
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(0)

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: 0,
        data: { b: "test" }.to_json,
        owner: "hijklmnop"
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(1)

      expect(DraftSequence.current(user, "abc")).to eq(1)

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: 1,
        data: { c: "test" }.to_json,
        owner: "hijklmnop"
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(2)

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: 2,
        data: { c: "test" }.to_json,
        owner: "abc"
      }

      expect(response.status).to eq(200)
      expect(response.parsed_body["draft_sequence"]).to eq(3)
    end

    it 'raises an error for out-of-sequence draft setting' do
      user = sign_in(Fabricate(:user))
      seq = DraftSequence.next!(user, "abc")
      Draft.set(user, "abc", seq, { b: "test" }.to_json)

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: seq - 1,
        data: { a: "test" }.to_json
      }

      expect(response.status).to eq(409)

      post "/drafts.json", params: {
        draft_key: "abc",
        sequence: seq + 1,
        data: { a: "test" }.to_json
      }

      expect(response.status).to eq(409)
    end

    context "when data is too big" do
      let(:user) { Fabricate(:user) }
      let(:data) { "a" * (SiteSetting.max_draft_length + 1) }

      before do
        SiteSetting.max_draft_length = 500
        sign_in(user)
      end

      it "returns an error" do
        post "/drafts.json",
             params: {
               draft_key: "xyz",
               data: { reply: data }.to_json,
               sequence: 0,
             }
        expect(response).to have_http_status :bad_request
      end
    end

    context "when data is not too big" do
      context "when data is not proper JSON" do
        let(:user) { Fabricate(:user) }
        let(:data) { "not-proper-json" }

        before { sign_in(user) }

        it "returns an error" do
          post "/drafts.json", params: { draft_key: "xyz", data: data, sequence: 0 }
          expect(response).to have_http_status :bad_request
        end
      end
    end
  end

  describe "#destroy" do
    it 'destroys drafts when required' do
      user = sign_in(Fabricate(:user))
      Draft.set(user, 'xxx', 0, 'hi')
      delete "/drafts/xxx.json", params: { sequence: 0 }
      expect(response.status).to eq(200)
      expect(Draft.get(user, 'xxx', 0)).to eq(nil)
    end
  end
end
