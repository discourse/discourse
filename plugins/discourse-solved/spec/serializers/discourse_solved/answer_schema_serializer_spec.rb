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
end
