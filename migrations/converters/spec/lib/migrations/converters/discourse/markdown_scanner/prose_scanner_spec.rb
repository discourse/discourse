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

  def run(scanner_class, input)
    nodes = []
    scanner =
      scanner_class.new(detectors: build_detectors) do |node, source|
        nodes << [node.class, source]
        "«#{nodes.size}»"
      end
    [scanner.scan(input), nodes]
  end

  # The prose walk exists because on gate-classified prose the full scanner's
  # code machinery can never engage; these inputs are that class, so the two
  # walks must agree byte for byte — on output and on every deferred node.
  # Grown over time, this is the fuzz corpus for the equivalence claim.
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

  it "produces the full scanner's exact output and nodes on danger-free input" do
    prose_inputs.each do |input|
      prose_output, prose_nodes = run(described_class, input)
      full_output, full_nodes = run(scanner_module::Scanner, input)

      expect(prose_output).to eq(full_output), "output diverged for #{input.inspect}"
      expect(prose_nodes).to eq(full_nodes), "nodes diverged for #{input.inspect}"
    end
  end

  it "replaces detected constructs and returns everything else verbatim" do
    output, nodes = run(described_class, "hi @alice, see #support :parrot:")

    expect(output).to eq("hi «1», see «2» «3»")
    expect(nodes.map(&:last)).to eq(%w[@alice #support :parrot:])
  end

  it "hands the verbatim matched slice to the block" do
    _, nodes = run(described_class, %{[quote="alice"]\nx\n[/quote]})

    expect(nodes.first.last).to eq(%{[quote="alice"]})
  end
end
