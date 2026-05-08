# frozen_string_literal: true

RSpec.describe DiscourseSolved::AcceptedAnswerSerializer do
  fab!(:user)
  fab!(:accepter, :user)
  fab!(:post) { Fabricate(:post, user: user, like_count: 3) }

  subject(:json) do
    described_class.new(post, root: false, accepter:).serializable_hash.deep_stringify_keys
  end

  it "includes expected default attributes" do
    expect(json["id"]).to eq(post.id)
    expect(json["post_number"]).to eq(post.post_number)
    expect(json["topic_id"]).to eq(post.topic_id)
    expect(json["url"]).to eq(post.url)
    expect(json["username"]).to eq(user.username)
    expect(json["name"]).to eq(user.name)
    expect(json["created_at"]).to eq(post.created_at)
    expect(json["cooked"]).to eq(post.cooked)
    expect(json).not_to have_key("accepter_name")
    expect(json).not_to have_key("accepter_username")
  end

  context "when show_who_marked_solved is enabled" do
    before { SiteSetting.show_who_marked_solved = true }

    it "includes the accepter name and username" do
      expect(json["accepter_username"]).to eq(accepter.username)
      expect(json["accepter_name"]).to eq(accepter.name)
    end
  end

  context "when solved_quote_length is disabled" do
    before { SiteSetting.solved_quote_length = 0 }

    it "does not include cooked content" do
      expect(json).not_to have_key("cooked")
    end
  end
end
