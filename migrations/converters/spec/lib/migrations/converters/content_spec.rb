# frozen_string_literal: true

RSpec.describe Migrations::Converters::Content do
  describe "#to_markdown without an embed sink" do
    subject(:cooker) { described_class.new(format: :bbcode) }

    it "cooks BBCode to Discourse Markdown" do
      expect(cooker.to_markdown("[b]hi[/b] and [url=https://example.com]a link[/url]")).to eq(
        "**hi** and [a link](https://example.com)",
      )
    end

    it "raises for an unknown source format" do
      expect { described_class.new(format: :wikitextish) }.to raise_error(
        described_class::UnknownFormat,
      )
    end
  end

  describe "#to_markdown deferring embeds into an EmbedBuffer" do
    subject(:cooker) { described_class.new(format: :bbcode) }

    let(:buffer) { Migrations::Converters::EmbedBuffer.new }

    it "defers an attributed quote, recording the linkage and preserving the body" do
      raw =
        cooker.to_markdown(
          '[quote="John, post:12, topic:34, username:john"]quoted body[/quote]',
          on_embed: buffer,
        )

      expect(buffer.quotes.size).to eq(1)
      descriptor = buffer.quotes.first
      expect(descriptor[:quoted_post_id]).to eq("12")
      expect(descriptor[:quoted_username]).to eq("John")

      # The token stands in for the opening tag; the body and closer remain.
      expect(raw).to include(descriptor[:placeholder])
      expect(raw).to include("quoted body")
      expect(raw).to include("[/quote]")
    end

    it "renders an unattributed quote natively (nothing to remap)" do
      raw = cooker.to_markdown("[quote]just text[/quote]", on_embed: buffer)

      expect(buffer).to be_empty
      expect(Migrations::Placeholder).not_to be_include(raw)
    end

    it "defers links only when asked via defer:" do
      raw =
        cooker.to_markdown(
          "see [url=https://example.com/t/5]here[/url]",
          on_embed: buffer,
          defer: %i[link],
        )

      expect(buffer.links.size).to eq(1)
      descriptor = buffer.links.first
      expect(descriptor[:url]).to eq("https://example.com/t/5")
      expect(descriptor[:text]).to eq("here")
      expect(raw).to include(descriptor[:placeholder])
    end

    it "leaves links alone by default" do
      raw = cooker.to_markdown("see [url=https://example.com]here[/url]", on_embed: buffer)

      expect(buffer.links).to be_empty
      expect(raw).to eq("see [here](https://example.com)")
    end

    # The contract: every token in the cooked raw maps to exactly one recorded
    # linkage descriptor.
    it "keeps placeholders and linkage rows one-to-one" do
      raw =
        cooker.to_markdown(
          'a [quote="A, post:1, topic:2, username:a"]q[/quote] b ' \
            "[url=https://example.com/t/9]L[/url] c",
          on_embed: buffer,
          defer: %i[quote link],
        )

      expect(Migrations::Placeholder.scan(raw)).to match_array(buffer.placeholders)
    end
  end

  describe ".embed_handlers extraction" do
    # Upload and Mention nodes don't arise from BBCode, so exercise their
    # extraction lambdas directly against the real AST nodes.
    let(:sink) { Migrations::Converters::EmbedBuffer.new }

    it "maps an Upload node's sha1 to upload_id" do
      _node_class, extract = described_class.embed_handlers.fetch(:upload)
      node = Markbridge::AST::Upload.new(sha1: "abc123", filename: "x.png")

      token = extract.call(sink, node, nil)

      expect(sink.uploads).to contain_exactly({ placeholder: token, upload_id: "abc123" })
    end

    it "maps a Mention node's type and name" do
      _node_class, extract = described_class.embed_handlers.fetch(:mention)
      node = Markbridge::AST::Mention.new(name: "gerhard", type: :user)

      token = extract.call(sink, node, nil)

      expect(sink.mentions).to contain_exactly(
        { placeholder: token, mention_type: "user", target_id: nil, name: "gerhard" },
      )
    end
  end
end
