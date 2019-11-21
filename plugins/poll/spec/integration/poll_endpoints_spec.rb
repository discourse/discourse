# frozen_string_literal: true

require "rails_helper"

describe "DiscoursePoll endpoints" do
  describe "fetch voters for a poll" do
    let(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post, raw: "[poll public=true]\n- A\n- B\n[/poll]") }
    let(:option_a) { "5c24fc1df56d764b550ceae1b9319125" }
    let(:option_b) { "e89dec30bbd9bf50fabf6a05b4324edf" }

    it "should return the right response" do
      DiscoursePoll::Poll.vote(
        post.id,
        DiscoursePoll::DEFAULT_POLL_NAME,
        [option_a],
        user
      )

      get "/polls/voters.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME
      }

      expect(response.status).to eq(200)

      poll = JSON.parse(response.body)["voters"]
      option = poll[option_a]

      expect(option.length).to eq(1)
      expect(option.first["id"]).to eq(user.id)
      expect(option.first["username"]).to eq(user.username)
    end

    it 'should return the right response for a single option' do
      DiscoursePoll::Poll.vote(
        post.id,
        DiscoursePoll::DEFAULT_POLL_NAME,
        [option_a, option_b],
        user
      )

      get "/polls/voters.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
        option_id: option_b
      }

      expect(response.status).to eq(200)

      poll = JSON.parse(response.body)["voters"]

      expect(poll[option_a]).to eq(nil)

      option = poll[option_b]

      expect(option.length).to eq(1)
      expect(option.first["id"]).to eq(user.id)
      expect(option.first["username"]).to eq(user.username)
    end

    describe 'when post_id is blank' do
      it 'should raise the right error' do
        get "/polls/voters.json", params: { poll_name: DiscoursePoll::DEFAULT_POLL_NAME }
        expect(response.status).to eq(400)
      end
    end

    describe 'when post_id is not valid' do
      it 'should raise the right error' do
        get "/polls/voters.json", params: {
          post_id: -1,
          poll_name: DiscoursePoll::DEFAULT_POLL_NAME
        }
        expect(response.status).to eq(422)
        expect(response.body).to include('post_id')
      end
    end

    describe 'when poll_name is blank' do
      it 'should raise the right error' do
        get "/polls/voters.json", params: { post_id: post.id }
        expect(response.status).to eq(400)
      end
    end

    describe 'when poll_name is not valid' do
      it 'should raise the right error' do
        get "/polls/voters.json", params: { post_id: post.id, poll_name: 'wrongpoll' }
        expect(response.status).to eq(422)
        expect(response.body).to include('poll_name')
      end
    end

    context "number poll" do
      let(:post) { Fabricate(:post, raw: "[poll type=number min=1 max=20 step=1 public=true]\n[/poll]") }

      it 'should return the right response' do
        post

        DiscoursePoll::Poll.vote(
          post.id,
          DiscoursePoll::DEFAULT_POLL_NAME,
          ["4d8a15e3cc35750f016ce15a43937620"],
          user
        )

        get "/polls/voters.json", params: {
          post_id: post.id,
          poll_name: DiscoursePoll::DEFAULT_POLL_NAME
        }

        expect(response.status).to eq(200)

        poll = JSON.parse(response.body)["voters"]

        expect(poll.first["id"]).to eq(user.id)
        expect(poll.first["username"]).to eq(user.username)
      end
    end
  end

  describe "#grouped_poll_results" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) }
    fab!(:post) { Fabricate(:post, raw: "[poll public=true]\n- A\n- B\n[/poll]") }
    let(:option_a) { "5c24fc1df56d764b550ceae1b9319125" }
    let(:option_b) { "e89dec30bbd9bf50fabf6a05b4324edf" }

    before do
      user_votes = {
        user_0: option_a,
        user_1: option_a,
        user_2: option_b,
      }
      [user1, user2, user3].each_with_index do |user, index|
        DiscoursePoll::Poll.vote(
          post.id,
          DiscoursePoll::DEFAULT_POLL_NAME,
          [user_votes["user_#{index}".to_sym]],
          user
        )
        UserCustomField.create(user_id: user.id, name: "something", value: "value#{index}")
      end

      # Add another user to one of the fields to prove it groups users properly
      DiscoursePoll::Poll.vote(
        post.id,
        DiscoursePoll::DEFAULT_POLL_NAME,
        [option_a, option_b],
        user4
      )
      UserCustomField.create(user_id: user4.id, name: "something", value: "value1")
    end

    it "returns grouped poll results based on user field" do
      SiteSetting.poll_groupable_user_fields = "something"

      get "/polls/grouped_poll_results.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
        user_field_name: "something"
      }

      expect(response.status).to eq(200)
      expect(JSON.parse(response.body).deep_symbolize_keys).to eq(
        grouped_results: [
          { group: "Value0", options: [{ digest: option_a, html: "A", votes: 1 }, { digest: option_b, html: "B", votes: 0 }] },
          { group: "Value1", options: [{ digest: option_a, html: "A", votes: 2 }, { digest: option_b, html: "B", votes: 1 }] },
          { group: "Value2", options: [{ digest: option_a, html: "A", votes: 0 }, { digest: option_b, html: "B", votes: 1 }] },
        ]
      )
    end

    it "returns an error when poll_groupable_user_fields is empty" do
      SiteSetting.poll_groupable_user_fields = ""
      get "/polls/grouped_poll_results.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
        user_field_name: "something"
      }

      expect(response.status).to eq(422)
      expect(response.body).to include('user_field_name')
    end
  end
end
