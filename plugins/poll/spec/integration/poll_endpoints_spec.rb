require "rails_helper"

describe "DiscoursePoll endpoints" do
  describe "fetch voters for a poll" do
    let(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post, raw: "[poll public=true]\n- A\n- B\n[/poll]") }

    it "should return the right response" do
      DiscoursePoll::Poll.vote(
        post.id,
        DiscoursePoll::DEFAULT_POLL_NAME,
        ["5c24fc1df56d764b550ceae1b9319125"],
        user
      )

      get "/polls/voters.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME
      }

      expect(response.status).to eq(200)

      poll = JSON.parse(response.body)[DiscoursePoll::DEFAULT_POLL_NAME]
      option = poll["5c24fc1df56d764b550ceae1b9319125"]

      expect(option.length).to eq(1)
      expect(option.first["id"]).to eq(user.id)
      expect(option.first["username"]).to eq(user.username)
    end

    it 'should return the right response for a single option' do
      DiscoursePoll::Poll.vote(
        post.id,
        DiscoursePoll::DEFAULT_POLL_NAME,
        ["5c24fc1df56d764b550ceae1b9319125", "e89dec30bbd9bf50fabf6a05b4324edf"],
        user
      )

      get "/polls/voters.json", params: {
        post_id: post.id,
        poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
        option_id: 'e89dec30bbd9bf50fabf6a05b4324edf'
      }

      expect(response.status).to eq(200)

      poll = JSON.parse(response.body)[DiscoursePoll::DEFAULT_POLL_NAME]

      expect(poll['5c24fc1df56d764b550ceae1b9319125']).to eq(nil)

      option = poll['e89dec30bbd9bf50fabf6a05b4324edf']

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
        expect(response.status).to eq(400)
        expect(response.body).to include('post_id is invalid')
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
        expect(response.status).to eq(400)
        expect(response.body).to include('poll_name is invalid')
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

        poll = JSON.parse(response.body)[DiscoursePoll::DEFAULT_POLL_NAME]

        expect(poll.first["id"]).to eq(user.id)
        expect(poll.first["username"]).to eq(user.username)
      end
    end
  end
end
