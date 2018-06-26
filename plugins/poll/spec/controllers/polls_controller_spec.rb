require "rails_helper"
require_relative "../helpers"

describe ::DiscoursePoll::PollsController do
  routes { ::DiscoursePoll::Engine.routes }

  let!(:user) { log_in }
  let(:topic) { Fabricate(:topic) }
  let(:poll)  { Fabricate(:post, topic: topic, user: user, raw: "[poll]\n- A\n- B\n[/poll]") }
  let(:multi_poll)  { Fabricate(:post, topic: topic, user: user, raw: "[poll min=1 max=2 type=multiple public=true]\n- A\n- B\n[/poll]") }

  describe "#vote" do

    it "works" do
      MessageBus.expects(:publish)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["poll"]["name"]).to eq("poll")
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["vote"]).to eq(["5c24fc1df56d764b550ceae1b9319125"])
    end

    it "requires at least 1 valid option" do
      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["A", "B"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.requires_at_least_1_valid_option"))
    end

    it "supports vote changes" do
      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).to eq(200)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["e89dec30bbd9bf50fabf6a05b4324edf"]
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["poll"]["options"][0]["votes"]).to eq(0)
      expect(json["poll"]["options"][1]["votes"]).to eq(1)
    end

    it "works even if topic is closed" do
      topic.update_attribute(:closed, true)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).to eq(200)
    end

    it "ensures topic is not archived" do
      topic.update_attribute(:archived, true)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["A"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.topic_must_be_open_to_vote"))
    end

    it "ensures post is not trashed" do
      poll.trash!

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["A"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.post_is_deleted"))
    end

    it "ensures user can post in topic" do
      Guardian.any_instance.expects(:can_create_post?).returns(false)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["A"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.user_cant_post_in_topic"))
    end

    it "ensures polls are associated with the post" do
      put :vote, params: {
        post_id: Fabricate(:post).id, poll_name: "foobar", options: ["A"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.no_polls_associated_with_this_post"))
    end

    it "checks the name of the poll" do
      put :vote, params: {
        post_id: poll.id, poll_name: "foobar", options: ["A"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.no_poll_with_this_name", name: "foobar"))
    end

    it "ensures poll is open" do
      closed_poll = create_post(raw: "[poll status=closed]\n- A\n- B\n[/poll]")

      put :vote, params: {
        post_id: closed_poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.poll_must_be_open_to_vote"))
    end

    it "doesn't discard anonymous votes when someone votes" do
      default_poll = poll.custom_fields["polls"]["poll"]
      add_anonymous_votes(poll, default_poll, 17, "5c24fc1df56d764b550ceae1b9319125" => 11, "e89dec30bbd9bf50fabf6a05b4324edf" => 6)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(18)
      expect(json["poll"]["options"][0]["votes"]).to eq(12)
      expect(json["poll"]["options"][1]["votes"]).to eq(6)
    end

    it "tracks the users ids for public polls" do
      public_poll = Fabricate(:post, topic_id: topic.id, user_id: user.id, raw: "[poll public=true]\n- A\n- B\n[/poll]")
      body = { post_id: public_poll.id, poll_name: "poll" }

      message = MessageBus.track_publish do
        put :vote,
          params: body.merge(options: ["5c24fc1df56d764b550ceae1b9319125"]),
          format: :json
      end.first

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["poll"]["options"][0]["votes"]).to eq(1)
      expect(json["poll"]["options"][1]["votes"]).to eq(0)
      expect(json["poll"]["options"][0]["voter_ids"]).to eq([user.id])
      expect(json["poll"]["options"][1]["voter_ids"]).to eq([])
      expect(message.data[:post_id].to_i).to eq(public_poll.id)
      expect(message.data[:user][:id].to_i).to eq(user.id)

      put :vote,
        params: body.merge(options: ["e89dec30bbd9bf50fabf6a05b4324edf"]),
        format: :json

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["poll"]["options"][0]["votes"]).to eq(0)
      expect(json["poll"]["options"][1]["votes"]).to eq(1)
      expect(json["poll"]["options"][0]["voter_ids"]).to eq([])
      expect(json["poll"]["options"][1]["voter_ids"]).to eq([user.id])

      another_user = Fabricate(:user)
      log_in_user(another_user)

      put :vote,
        params: body.merge(options: ["e89dec30bbd9bf50fabf6a05b4324edf", "5c24fc1df56d764b550ceae1b9319125"]),
        format: :json

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(2)
      expect(json["poll"]["options"][0]["votes"]).to eq(1)
      expect(json["poll"]["options"][1]["votes"]).to eq(2)
      expect(json["poll"]["options"][0]["voter_ids"]).to eq([another_user.id])
      expect(json["poll"]["options"][1]["voter_ids"]).to eq([user.id, another_user.id])
    end
  end

  describe "#toggle_status" do

    it "works for OP" do
      MessageBus.expects(:publish)

      put :toggle_status, params: {
        post_id: poll.id, poll_name: "poll", status: "closed"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["poll"]["status"]).to eq("closed")
    end

    it "works for staff" do
      log_in(:moderator)
      MessageBus.expects(:publish)

      put :toggle_status, params: {
        post_id: poll.id, poll_name: "poll", status: "closed"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["poll"]["status"]).to eq("closed")
    end

    it "ensures post is not trashed" do
      poll.trash!

      put :toggle_status, params: {
        post_id: poll.id, poll_name: "poll", status: "closed"
      }, format: :json

      expect(response.status).not_to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.post_is_deleted"))
    end

  end

  describe "votes" do

    it "correctly handles offset" do

      first = "5c24fc1df56d764b550ceae1b9319125"
      second = "e89dec30bbd9bf50fabf6a05b4324edf"

      user1 = log_in

      put :vote, params: {
        post_id: multi_poll.id, poll_name: "poll", options: [first]
      }, format: :json

      expect(response.status).to eq(200)

      user2 = log_in

      put :vote, params: {
        post_id: multi_poll.id, poll_name: "poll", options: [first]
      }, format: :json

      expect(response.status).to eq(200)

      user3 = log_in

      put :vote, params: {
        post_id: multi_poll.id,
        poll_name: "poll",
        options: [first, second]
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: 'poll', post_id: multi_poll.id, voter_limit: 2
      }, format: :json

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      # no user3 cause voter_limit is 2
      expect(json["poll"][first].map { |h| h["id"] }.sort).to eq([user1.id, user2.id])
      expect(json["poll"][second].map { |h| h["id"] }).to eq([user3.id])
    end

  end

end
