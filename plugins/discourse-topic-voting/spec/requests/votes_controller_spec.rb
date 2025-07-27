# frozen_string_literal: true

describe DiscourseTopicVoting::VotesController do
  let(:user) { Fabricate(:user) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id) }

  before do
    DiscourseTopicVoting::CategorySetting.create!(category: category)
    Category.reset_voting_cache
    SiteSetting.topic_voting_show_who_voted = true
    SiteSetting.topic_voting_enabled = true
    sign_in(user)
  end

  it "does not allow voting if voting is not enabled" do
    SiteSetting.topic_voting_enabled = false
    post "/voting/vote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(404)
  end

  it "can correctly show deal with voting workflow" do
    SiteSetting.public_send "topic_voting_tl#{user.trust_level}_vote_limit=", 2

    post "/voting/vote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(200)

    post "/voting/vote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(403)
    expect(topic.reload.vote_count).to eq(1)
    expect(user.reload.vote_count).to eq(1)

    get "/voting/who.json", params: { topic_id: topic.id }
    expect(response.status).to eq(200)
    json = JSON.parse(response.body)
    expect(json.length).to eq(1)
    expect(json.first.keys.sort).to eq(%w[avatar_template id name username])
    expect(json.first["id"]).to eq(user.id)

    post "/voting/unvote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(200)

    expect(topic.reload.vote_count).to eq(0)
    expect(user.reload.vote_count).to eq(0)
  end

  it "triggers a topic_upvote webhook when voting" do
    Fabricate(:topic_voting_web_hook)
    post "/voting/vote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(200)

    job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first
    expect(job_args["event_name"]).to eq("topic_upvote")
    payload = JSON.parse(job_args["payload"])
    expect(payload["topic_id"]).to eq(topic.id)
    expect(payload["topic_slug"]).to eq(topic.slug)
    expect(payload["voter_id"]).to eq(user.id)
    expect(payload["vote_count"]).to eq(1)
  end

  it "triggers a topic_unvote webhook when unvoting" do
    Fabricate(:topic_voting_web_hook)
    post "/voting/unvote.json", params: { topic_id: topic.id }
    expect(response.status).to eq(200)
    job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first
    expect(job_args["event_name"]).to eq("topic_unvote")
    payload = JSON.parse(job_args["payload"])
    expect(payload["topic_id"]).to eq(topic.id)
    expect(payload["topic_slug"]).to eq(topic.slug)
    expect(payload["voter_id"]).to eq(user.id)
    expect(payload["vote_count"]).to eq(0)
  end
end
