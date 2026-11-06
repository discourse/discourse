# frozen_string_literal: true

RSpec.describe DiscourseSolved::AnswerSchemaSerializer do
  fab!(:post) { Fabricate(:post, like_count: 5) }

  subject(:json) { described_class.new(post, root: false).serializable_hash.deep_stringify_keys }

  it "includes the Answer @type" do
    expect(json["@type"]).to eq("Answer")
  end

  it "serializes the post attributes" do
    expect(json["text"]).to be_present
    expect(json["upvoteCount"]).to eq(5)
    expect(json["datePublished"]).to eq(post.created_at)
    expect(json["url"]).to eq(post.full_url)
  end

  it "serializes the author" do
    expect(json["author"]).to eq(
      { "@type" => "Person", "name" => post.user.username, "url" => post.user.full_url },
    )
  end

  context "with a post longer than the excerpt limit" do
    fab!(:long_post) { Fabricate(:post, raw: Array.new(120) { |i| "word#{i}" }.join(" ")) }

    subject(:json) do
      described_class.new(long_post, root: false).serializable_hash.deep_stringify_keys
    end

    it "uses the full text of the post" do
      expect(long_post.raw.length).to be > SiteSetting.post_excerpt_maxlength
      expect(json["text"]).to eq(long_post.raw)
    end
  end
end
