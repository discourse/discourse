# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownRenderer do
  describe "#to_markdown without an embed sink" do
    subject(:renderer) { described_class.new(format: :bbcode) }

    it "renders BBCode to Discourse Markdown" do
      expect(renderer.to_markdown("[b]hi[/b] and [url=https://example.com]a link[/url]")).to eq(
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
    subject(:renderer) { described_class.new(format: :bbcode) }

    let(:buffer) do
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    end

    it "defers an attributed quote, recording the linkage and preserving the body" do
      raw =
        renderer.to_markdown(
          '[quote="John, post:12, topic:34, username:john"]quoted body[/quote]',
          on_embed: buffer,
        )

      expect(buffer.quotes.size).to eq(1)
      descriptor = buffer.quotes.first
      # The Discourse attribution format carries coordinates: `post:` is a post
      # number, `topic:` a topic id.
      expect(descriptor[:quoted_post_id]).to be_nil
      expect(descriptor[:quoted_topic_id]).to eq(34)
      expect(descriptor[:quoted_post_number]).to eq(12)
      expect(descriptor[:quoted_username]).to eq("John")

      # The token stands in for the opening tag; the body and closer remain.
      expect(raw).to include(descriptor[:placeholder])
      expect(raw).to include("quoted body")
      expect(raw).to include("[/quote]")
    end

    it "drops an attribution number too large for an id column" do
      # Meta really has a post titled like this; SQLite raises binding a bignum.
      raw =
        renderer.to_markdown(
          '[quote="A, post:77777777777777777789999, topic:2"]q[/quote]',
          on_embed: buffer,
        )

      descriptor = buffer.quotes.first
      expect(descriptor[:quoted_post_number]).to be_nil
      expect(descriptor[:quoted_topic_id]).to eq(2)
      expect(descriptor[:quoted_username]).to eq("A")
      expect(raw).to include(descriptor[:placeholder])
    end

    it "renders an unattributed quote natively (nothing to remap)" do
      raw = renderer.to_markdown("[quote]just text[/quote]", on_embed: buffer)

      expect(buffer).to be_empty
      expect(Migrations::Placeholder).not_to be_include(raw)
    end

    it "defers links only when asked via defer:" do
      raw =
        renderer.to_markdown(
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

    it "defers a link whose label is simple inline formatting" do
      raw =
        renderer.to_markdown(
          "see [url=https://example.com/t/5][b]here[/b][/url]",
          on_embed: buffer,
          defer: %i[link],
        )

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to eq("**here**")
      expect(raw).to include(buffer.links.first[:placeholder])
    end

    it "defers a link whose quote label the normalizer hoisted out" do
      # Markbridge's normalizer pulls the quote out of the link before we
      # render, so the link arrives with an empty (hence deferrable) label
      # and the quote defers separately, as a sibling in the raw.
      raw =
        renderer.to_markdown(
          '[url=https://example.com][quote="A, post:1, topic:2"]q[/quote][/url]',
          on_embed: buffer,
          defer: %i[quote link],
        )

      expect(buffer.links).to contain_exactly(hash_including(url: "https://example.com", text: nil))
      expect(buffer.quotes.size).to eq(1)
      expect(raw).to include(buffer.links.first[:placeholder])
      expect(raw).to include(buffer.quotes.first[:placeholder])
    end

    it "records a bare link when the normalizer hoists the image out" do
      raw =
        renderer.to_markdown(
          "[url=https://example.com][img]https://example.com/pic.png[/img][/url]",
          on_embed: buffer,
          defer: %i[link],
        )

      # The link is recorded label-less (a bare URL at import); the image
      # follows it in the raw instead of cooking into a clickable image.
      expect(buffer.links).to contain_exactly(hash_including(url: "https://example.com", text: nil))
      expect(raw).to include(buffer.links.first[:placeholder])
      expect(raw).to include("![](https://example.com/pic.png)")
    end

    it "records a bare link when the image sat inside formatting" do
      raw =
        renderer.to_markdown(
          "[url=https://example.com][b][img]https://example.com/pic.png[/img][/b][/url]",
          on_embed: buffer,
          defer: %i[link],
        )

      expect(buffer.links).to contain_exactly(hash_including(url: "https://example.com", text: nil))
      expect(raw).to include(buffer.links.first[:placeholder])
      expect(raw).to include("![](https://example.com/pic.png)")
      expect(raw).not_to include("****")
    end

    it "records a bare URL's text as nil so the importer re-emits it bare" do
      renderer.to_markdown(
        "see [url=https://example.com/t/5]https://example.com/t/5[/url]",
        on_embed: buffer,
        defer: %i[link],
      )

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to be_nil
    end

    it "records a text-less link's text as nil, not an empty string" do
      renderer.to_markdown(
        "see [url=https://example.com/t/5][/url]",
        on_embed: buffer,
        defer: %i[link],
      )

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to be_nil
    end

    it "leaves links alone by default" do
      raw = renderer.to_markdown("see [url=https://example.com]here[/url]", on_embed: buffer)

      expect(buffer.links).to be_empty
      expect(raw).to eq("see [here](https://example.com)")
    end

    # The contract: every token in the rendered raw maps to exactly one recorded
    # linkage descriptor.
    it "keeps placeholders and linkage rows one-to-one" do
      raw =
        renderer.to_markdown(
          'a [quote="A, post:1, topic:2, username:a"]q[/quote] b ' \
            "[url=https://example.com/t/9]L[/url] c",
          on_embed: buffer,
          defer: %i[quote link],
        )

      expect(Migrations::Placeholder.scan(raw)).to match_array(buffer.placeholders)
    end
  end

  describe ".normalizer" do
    it "textifies a mention inside a link so the label stays deferrable" do
      node = Markbridge::AST::Url.new(href: "https://example.com")
      node << Markbridge::AST::Text.new("hi ")
      node << Markbridge::AST::Mention.new(name: "sam", type: :user)
      document = Markbridge::AST::Document.new
      document << node

      described_class.normalizer.normalize(document)

      # Textified and coalesced with the neighbouring text: one plain-text
      # label, which the :link handler will accept for deferral.
      expect(node.children.map(&:class)).to eq([Markbridge::AST::Text])
      expect(node.children.first.text).to eq("hi @sam")
    end

    it "is what to_markdown converts through" do
      allow(Markbridge).to receive(:convert).and_call_original

      described_class.new(format: :bbcode).to_markdown("plain")

      expect(Markbridge).to have_received(:convert).with(
        "plain",
        hash_including(normalize: described_class.normalizer),
      )
    end
  end

  describe ".embed_handlers extraction" do
    # Upload and Mention nodes don't arise from BBCode, so exercise their
    # extraction lambdas directly against the real AST nodes.
    let(:sink) do
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    end

    it "maps an Upload node's sha1 to upload_id" do
      _node_class, extract = described_class.embed_handlers.fetch(:upload)
      node = Markbridge::AST::Upload.new(sha1: "abc123", filename: "x.png")

      token = extract.call(sink, node, nil)

      expect(sink.uploads).to contain_exactly(
        { placeholder: token, upload_id: "abc123", original_markdown: nil },
      )
    end

    it "maps a Quote node's ids to quoted_post_id and quoted_user_id" do
      # BBCode can't carry them (phpBB-style id attribution arrives via the
      # TextFormatter parser), so exercise the lambda directly.
      _node_class, extract = described_class.embed_handlers.fetch(:quote)
      node = Markbridge::AST::Quote.new(username: "alice", post_id: 9001, user_id: 12)
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:with_parent).with(node).and_return(:child_context)
      allow(interface).to receive(:render_children).with(node, context: :child_context).and_return(
        "body",
      )

      extract.call(sink, node, interface)

      expect(sink.quotes).to contain_exactly(
        hash_including(quoted_post_id: 9001, quoted_user_id: 12, quoted_username: "alice"),
      )
    end

    it "defers a link whose label is single-line inline code" do
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      code = Markbridge::AST::Code.new << Markbridge::AST::Text.new("x")
      node << code
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_children).with(node).and_return("`x`")

      extract.call(sink, node, interface)

      expect(sink.links).to contain_exactly(hash_including(text: "`x`"))
    end

    it "falls back to native rendering for a label the normalizer has not cleaned" do
      # The normalizer hoists uploads out of links before rendering, so this
      # tree can't arrive through the pipeline — the fallback is defense in
      # depth for a direct/custom rendering path.
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      node << Markbridge::AST::Upload.new(sha1: "abc123", filename: "x.png")
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_default).with(node).and_return("NATIVE")

      result = extract.call(sink, node, interface)

      expect(result).to eq("NATIVE")
      expect(sink.links).to be_empty
    end

    it "falls back to native rendering for a label with multi-line code" do
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      node << (Markbridge::AST::Code.new << Markbridge::AST::Text.new("a\nb"))
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_default).with(node).and_return("NATIVE")

      result = extract.call(sink, node, interface)

      expect(result).to eq("NATIVE")
      expect(sink.links).to be_empty
    end

    it "falls back to native rendering for a label containing a mention" do
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      node << Markbridge::AST::Text.new("hi ")
      node << Markbridge::AST::Mention.new(name: "sam", type: :user)
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_default).with(node).and_return("NATIVE")

      result = extract.call(sink, node, interface)

      expect(result).to eq("NATIVE")
      expect(sink.links).to be_empty
    end

    it "maps a Mention node's type and name" do
      _node_class, extract = described_class.embed_handlers.fetch(:mention)
      node = Markbridge::AST::Mention.new(name: "gerhard", type: :user)

      token = extract.call(sink, node, nil)

      expect(sink.mentions).to contain_exactly(
        {
          placeholder: token,
          mention_type: Migrations::Database::IntermediateDB::Enums::MentionType::USER,
          target_id: nil,
          name: "gerhard",
        },
      )
    end
  end
end
