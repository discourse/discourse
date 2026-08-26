# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownEngine::Context do
  subject(:context) { described_class.new(bundle:, config:) }

  let(:bundle) { Migrations::Converters::MarkdownEngine::Bundle.load_or_build }
  let(:config) do
    Migrations::Converters::MarkdownEngine::Config.new(
      category_slugs: %w[support],
      tag_names: %w[bug],
      custom_emoji_names: %w[partyparrot],
    )
  end

  after { context.close }

  def scan_one(raw)
    context.scan([{ id: 1, raw: }]).first
  end

  it "extracts mentions with the block's line map" do
    result = scan_one("a paragraph\n\nwith @sam here")
    expect(result["blocks"]).to contain_exactly(
      a_hash_including("mentions" => ["@sam"], "map" => [2, 3]),
    )
  end

  it "shields code spans and code blocks the way core does" do
    result = scan_one("`@code` and @prose\n\n```\n@fence\n```")
    expect(result["blocks"].map { |block| block["mentions"] }).to eq([["@prose"]])
    expect(result["blocks"].first["code"]).to eq(1)
    expect(result["blockTokens"]).to include(a_hash_including("type" => "fence", "map" => [2, 5]))
  end

  it "resolves hashtags against the source name sets only" do
    result = scan_one("#support #bug #unknown")
    expect(result["blocks"].first["hashtags"]).to contain_exactly(
      { "type" => "category", "slug" => "support" },
      { "type" => "tag", "slug" => "bug" },
    )
  end

  it "keeps unresolved short upload URLs as the construct value" do
    result = scan_one("![pic|100x100](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png)")
    expect(result["blocks"].first["images"]).to eq(%w[upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png])
  end

  it "collects linkified bare domains and explicit links" do
    result = scan_one("see meta.example.com/t/topic/123 and [x](https://example.com/page)")
    expect(result["blocks"].first["links"]).to eq(
      [
        # A linkified bare domain is its own label but exists once in the raw,
        # so it contributes no label occurrences.
        { "href" => "http://meta.example.com/t/topic/123", "labelHits" => 0 },
        { "href" => "https://example.com/page", "labelHits" => 0 },
      ],
    )
  end

  it "counts a self-link's destination appearing in its label" do
    result = scan_one("[https://example.com/page](https://example.com/page)")
    expect(result["blocks"].first["links"]).to eq(
      [{ "href" => "https://example.com/page", "labelHits" => 1 }],
    )
  end

  it "records quote extents from the mapped bbcode token" do
    result = scan_one(%{[quote="sam, post:1, topic:2"]\nquoted @sam\n[/quote]})
    expect(result["blockTokens"]).to include(
      a_hash_including("type" => "bbcode_open", "tag" => "blockquote", "map" => [0, 2]),
    )
    expect(result["blocks"].first).to include("mentions" => ["@sam"], "map" => [1, 2])
  end

  it "recognizes standard, unicode, and source custom emoji" do
    result = scan_one(":smile: :partyparrot: 😀 :not_an_emoji:")
    expect(result["blocks"].first["emojis"]).to eq(%w[smile partyparrot grinning_face])
  end

  it "scrubs invalid encoding instead of raising" do
    raw = "hi @sam \xC3".b
    expect(scan_one(raw)["blocks"].first["mentions"]).to eq(["@sam"])
  end

  it "returns post ids with their results" do
    results = context.scan([{ id: 7, raw: "@sam" }, { id: 9, raw: "plain" }])
    expect(results.map { |result| result["id"] }).to eq([7, 9])
  end

  it "refuses to scan after being discarded" do
    context.discard!
    expect { context.scan([{ id: 1, raw: "x" }]) }.to raise_error(described_class::DiscardedError)
  end
end
