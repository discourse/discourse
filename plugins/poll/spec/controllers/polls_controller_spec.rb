require "rails_helper"

describe ::DiscoursePoll::PollsController do
  routes { ::DiscoursePoll::Engine.routes }

  let!(:user) { log_in }
  let(:topic) { Fabricate(:topic) }
  let(:poll)  { Fabricate(:post, topic: topic, user: user, raw: "[poll]\n- A\n- B\n[/poll]") }
  let(:multi_poll)  { Fabricate(:post, topic: topic, user: user, raw: "[poll min=1 max=2 type=multiple public=true]\n- A\n- B\n[/poll]") }
  let(:public_poll_on_vote) { Fabricate(:post, topic: topic, user: user, raw: "[poll public=true results=on_vote]\n- A\n- B\n[/poll]") }
  let(:public_poll_on_close) { Fabricate(:post, topic: topic, user: user, raw: "[poll public=true results=on_close]\n- A\n- B\n[/poll]") }

  describe "#vote" do

    it "works" do
      message = MessageBus.track_publish do
        put :vote, params: {
          post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
        }, format: :json
      end.first

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["name"]).to eq("poll")
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["vote"]).to eq(["5c24fc1df56d764b550ceae1b9319125"])

      expect(message.channel).to eq("/polls/#{poll.topic_id}")
      expect(message.user_ids).to eq(nil)
      expect(message.group_ids).to eq(nil)
    end

    it "works in PM" do
      user2 = Fabricate(:user)
      topic = Fabricate(:private_message_topic, topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: user),
        Fabricate.build(:topic_allowed_user, user: user2)
      ])
      poll = Fabricate(:post, topic: topic, user: user, raw: "[poll]\n- A\n- B\n[/poll]")

      message = MessageBus.track_publish do
        put :vote, params: {
          post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
        }, format: :json
      end.first

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["name"]).to eq("poll")
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["vote"]).to eq(["5c24fc1df56d764b550ceae1b9319125"])

      expect(message.channel).to eq("/polls/#{poll.topic_id}")
      expect(message.user_ids).to contain_exactly(user.id, user2.id)
      expect(message.group_ids).to eq(nil)
    end

    it "works in secure categories" do
      group = Fabricate(:group)
      group.add_owner(user)
      category = Fabricate(:private_category, group: group)
      topic = Fabricate(:topic, category: category)
      poll = Fabricate(:post, topic: topic, user: user, raw: "[poll]\n- A\n- B\n[/poll]")

      message = MessageBus.track_publish do
        put :vote, params: {
          post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
        }, format: :json
      end.first

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["name"]).to eq("poll")
      expect(json["poll"]["voters"]).to eq(1)
      expect(json["vote"]).to eq(["5c24fc1df56d764b550ceae1b9319125"])

      expect(message.channel).to eq("/polls/#{poll.topic_id}")
      expect(message.user_ids).to eq(nil)
      expect(message.group_ids).to contain_exactly(group.id)
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

    it "works on closed topics" do
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
      the_poll = poll.polls.first
      the_poll.update_attribute(:anonymous_voters, 17)
      the_poll.poll_options[0].update_attribute(:anonymous_votes, 11)
      the_poll.poll_options[1].update_attribute(:anonymous_votes, 6)

      put :vote, params: {
        post_id: poll.id, poll_name: "poll", options: ["5c24fc1df56d764b550ceae1b9319125"]
      }, format: :json

      expect(response.status).to eq(200)

      json = ::JSON.parse(response.body)
      expect(json["poll"]["voters"]).to eq(18)
      expect(json["poll"]["options"][0]["votes"]).to eq(12)
      expect(json["poll"]["options"][1]["votes"]).to eq(6)
    end
  end

  describe "#toggle_status" do

    it "works for OP" do
      message = MessageBus.track_publish do
        put :toggle_status, params: {
          post_id: poll.id, poll_name: "poll", status: "closed"
        }, format: :json

        expect(response.status).to eq(200)
      end.first

      json = ::JSON.parse(response.body)
      expect(json["poll"]["status"]).to eq("closed")
      expect(message.channel).to eq("/polls/#{poll.topic_id}")
    end

    it "works for staff" do
      log_in(:moderator)

      message = MessageBus.track_publish do
        put :toggle_status, params: {
          post_id: poll.id, poll_name: "poll", status: "closed"
        }, format: :json

        expect(response.status).to eq(200)
      end.first

      json = ::JSON.parse(response.body)
      expect(json["poll"]["status"]).to eq("closed")
      expect(message.channel).to eq("/polls/#{poll.topic_id}")
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

  describe "#voters" do

    let(:first) { "5c24fc1df56d764b550ceae1b9319125" }
    let(:second) { "e89dec30bbd9bf50fabf6a05b4324edf" }

    it "correctly handles offset" do
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
        post_id: multi_poll.id, poll_name: "poll", options: [first, second]
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: 'poll', post_id: multi_poll.id, limit: 2
      }, format: :json

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      # no user3 cause voter_limit is 2
      expect(json["voters"][first].map { |h| h["id"] }).to contain_exactly(user1.id, user2.id)
      expect(json["voters"][second].map { |h| h["id"] }).to contain_exactly(user3.id)
    end

    it "ensures voters can only be seen after casting a vote" do
      put :vote, params: {
        post_id: public_poll_on_vote.id, poll_name: "poll", options: [first]
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: "poll", post_id: public_poll_on_vote.id
      }, format: :json

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      expect(json["voters"][first].size).to eq(1)

      user2 = log_in

      get :voters, params: {
        poll_name: "poll", post_id: public_poll_on_vote.id
      }, format: :json

      expect(response.status).to eq(422)

      put :vote, params: {
        post_id: public_poll_on_vote.id, poll_name: "poll", options: [second]
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: "poll", post_id: public_poll_on_vote.id
      }, format: :json

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      expect(json["voters"][first].size).to eq(1)
      expect(json["voters"][second].size).to eq(1)
    end

    it "ensures voters can only be seen when poll is closed" do
      put :vote, params: {
        post_id: public_poll_on_close.id, poll_name: "poll", options: [first]
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: "poll", post_id: public_poll_on_close.id
      }, format: :json

      expect(response.status).to eq(422)

      put :toggle_status, params: {
        post_id: public_poll_on_close.id, poll_name: "poll", status: "closed"
      }, format: :json

      expect(response.status).to eq(200)

      get :voters, params: {
        poll_name: "poll", post_id: public_poll_on_close.id
      }, format: :json

      expect(response.status).to eq(200)

      json = JSON.parse(response.body)

      expect(json["voters"][first].size).to eq(1)
    end

  end

end
