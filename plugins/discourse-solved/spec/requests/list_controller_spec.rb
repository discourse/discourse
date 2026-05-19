# frozen_string_literal: true

RSpec.describe ListController do
  fab!(:p1, :post)
  fab!(:p2) { Fabricate(:post, topic: p1.topic) }
  fab!(:p3) { Fabricate(:post, topic: p1.topic) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  it "shows the user who posted the accepted answer second" do
    TopicFeaturedUsers.ensure_consistency!
    DiscourseSolved::AcceptAnswer.call!(params: { post_id: p3.id }, guardian: p1.user.guardian)

    get "/latest.json"
    posters = response.parsed_body["topic_list"]["topics"].first["posters"]
    expect(posters[0]["user_id"]).to eq(p1.user_id)
    expect(posters[1]["user_id"]).to eq(p3.user_id)
    expect(posters[1]["description"]).to include("Accepted Answer")
    expect(posters[2]["user_id"]).to eq(p2.user_id)
  end

  describe "with multiple solutions enabled" do
    fab!(:p4) { Fabricate(:post, topic: p1.topic) }
    before { SiteSetting.solved_allow_multiple_solutions = true }
    it "shows the user who posted the accepted answers second" do
      TopicFeaturedUsers.ensure_consistency!
      DiscourseSolved::AcceptAnswer.call!(params: { post_id: p3.id }, guardian: p1.user.guardian)
      DiscourseSolved::AcceptAnswer.call!(params: { post_id: p4.id }, guardian: p1.user.guardian)

      get "/latest.json"
      posters = response.parsed_body["topic_list"]["topics"].first["posters"]
      expect(posters[0]["user_id"]).to eq(p1.user_id)

      accepted_user_ids =
        posters.filter_map { |p| p["description"].include?("Accepted Answer") ? p["user_id"] : nil }
      expect(accepted_user_ids).to include(p3.user_id, p4.user_id)

      expect(posters[3]["user_id"]).to eq(p2.user_id)
    end
  end
end
