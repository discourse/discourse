# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::ProseScanner do
  let(:scanner_module) { Migrations::Converters::Discourse::MarkdownScanner }

  let(:mention_names) do
    Migrations::CompactStringSet.new(
      %w[alice bob café_team].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end
  let(:hashtag_names) do
    Migrations::CompactStringSet.new(
      %w[support team:billing].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end

  def build_detectors
    [
      scanner_module::Detectors::Upload.new,
      scanner_module::Detectors::UploadUrl.new,
      scanner_module::Detectors::Quote.new,
      scanner_module::Detectors::InternalLink.new(
        hosts: {
          "forum.example.com" => nil,
        },
        base_prefix: nil,
        on_foreign_host: nil,
      ),
      scanner_module::Detectors::LinkSpan.new,
      scanner_module::Detectors::Mention.new(names: mention_names),
      scanner_module::Detectors::Hashtag.new(names: hashtag_names),
      scanner_module::Detectors::Emoji.new(names: %w[parrot]),
    ]
  end

  def run(input)
    nodes = []
    scanner =
      described_class.new(detectors: build_detectors) do |node, source|
        nodes << [node.class, source]
        "«#{nodes.size}»"
      end
    [scanner.scan(input), nodes]
  end

  def run_engine(input)
    detectors = build_detectors
    nodes = []
    scanner =
      scanner_module::EngineScanner.new(
        engine:
          MarkdownEngineHelper.context_for_names(
            hashtag_names: %w[support team:billing],
            custom_emoji_names: %w[parrot],
          ),
        detectors:,
        gate: scanner_module::TierGate.new(detectors:),
        mention_names:,
        hashtag_names:,
        custom_emoji_names: %w[parrot],
        internal_link_hosts: {
          "forum.example.com" => nil,
        },
      ) do |node, source|
        nodes << [node.class, source]
        "«#{nodes.size}»"
      end
    result = scanner.scan(input)
    [result, nodes]
  end

  # The prose walk exists because on gate-classified prose no code shielding
  # or link structure can be needed; the engine tier extracts from the same
  # input through the real parse, so on this class the two must agree byte for
  # byte — on output and on every deferred node. The engine is the oracle
  # here. Grown over time, this is the fuzz corpus for the tier-1 claim at
  # the scanner level (the extractor-level differential lives with the
  # RawExtractor specs).
  let(:prose_inputs) do
    [
      "plain text without anything",
      "hello @alice, how are you?",
      "unknown @stranger stays put",
      "@alice at the very start and @bob.",
      "hashtag #support and #team:billing::tag here",
      "not a hashtag: PR #123 and word#tag",
      "custom emoji :parrot: but standard :smile: stays",
      "a bare route /t/some-topic/55 in prose",
      "https://forum.example.com/t/topic/9 absolute link",
      "https://elsewhere.example.com/t/1 foreign host",
      "unicode names @café_team and boundaries ¡@alice!",
      %{[quote="alice, post:2, topic:7"]\nquoted words\n[/quote]},
      "adjacent constructs @alice#support :parrot:",
      "trailing @alice",
      "@",
      "#",
      ":",
      "",
    ]
  end

  it "produces the engine tier's exact output and nodes on danger-free input" do
    prose_inputs.each do |input|
      prose_output, prose_nodes = run(input)
      engine_result, engine_nodes = run_engine(input)

      expect(engine_result.refused?).to be(false), "engine refused #{input.inspect}"
      expect(prose_output).to eq(engine_result.output), "output diverged for #{input.inspect}"
      expect(prose_nodes).to eq(engine_nodes), "nodes diverged for #{input.inspect}"
    end
  end

  it "replaces detected constructs and returns everything else verbatim" do
    output, nodes = run("hi @alice, see #support :parrot:")

    expect(output).to eq("hi «1», see «2» «3»")
    expect(nodes.map(&:last)).to eq(%w[@alice #support :parrot:])
  end

  it "keeps the matched text verbatim when the block declines with nil" do
    nodes = []
    output =
      described_class
        .new(detectors: build_detectors) do |node, _source|
          nodes << node
          nil
        end
        .scan("héllo @alice there")

    expect(nodes.size).to eq(1)
    expect(output).to eq("héllo @alice there")
    expect(output).to be_valid_encoding
  end

  it "hands the verbatim matched slice to the block" do
    _, nodes = run(%{[quote="alice"]\nx\n[/quote]})

    expect(nodes.first.last).to eq(%{[quote="alice"]})
  end
end
