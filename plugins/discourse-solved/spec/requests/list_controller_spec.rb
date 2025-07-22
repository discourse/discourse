# frozen_string_literal: true

require "rails_helper"

RSpec.describe ListController do
  fab!(:p1) { Fabricate(:post) }
  fab!(:p2) { Fabricate(:post, topic: p1.topic) }
  fab!(:p3) { Fabricate(:post, topic: p1.topic) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  it "shows the user who posted the accepted answer second" do
    TopicFeaturedUsers.ensure_consistency!
    DiscourseSolved.accept_answer!(p3, p1.user, topic: p1.topic)

    get "/latest.json"
    posters = response.parsed_body["topic_list"]["topics"].first["posters"]
    expect(posters[0]["user_id"]).to eq(p1.user_id)
    expect(posters[1]["user_id"]).to eq(p3.user_id)
    expect(posters[1]["description"]).to include("Accepted Answer")
    expect(posters[2]["user_id"]).to eq(p2.user_id)
  end
end
