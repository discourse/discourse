# frozen_string_literal: true

RSpec.describe Migrations::Converters::MarkdownRenderer do
  describe "#to_markdown without an embed collector" do
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

    it "unwraps a link nested in a link (CommonMark legality)" do
      # A link inside a link is illegal Markdown; markbridge's default rules
      # unwrap the inner one, keeping only its label, so the outer link stays
      # the single link.
      expect(
        renderer.to_markdown("[url=https://a.com]outer [url=https://b.com]inner[/url] end[/url]"),
      ).to eq("[outer inner end](https://a.com)")
    end

    it "keeps a linked image inside the link" do
      # A linked image is legal Markdown and Discourse cooks it fine (the anchor
      # wraps the image), so the image stays nested inside the link.
      expect(
        renderer.to_markdown(
          "[url=https://example.com][img]https://example.com/pic.png[/img][/url]",
        ),
      ).to eq("[![](https://example.com/pic.png)](https://example.com)")
    end

    it "unwraps a self-link so the image stands alone" do
      # The image links to its own source URL — the link is noise. Dropping it
      # leaves a bare image, which gets Discourse's lightbox on import.
      expect(
        renderer.to_markdown("[url=https://x/pic.png][img]https://x/pic.png[/img][/url]"),
      ).to eq("![](https://x/pic.png)")
    end

    it "keeps the link when the image points elsewhere" do
      # Only an exact src == href match is a self-link; a near miss (image is a
      # different resource on the same host) keeps the link.
      expect(renderer.to_markdown("[url=https://x/page][img]https://x/pic.png[/img][/url]")).to eq(
        "[![](https://x/pic.png)](https://x/page)",
      )
    end
  end

  describe "#to_markdown deferring embeds into an EmbedBuffer" do
    subject(:renderer) { described_class.new(format: :bbcode, embeds: buffer) }

    let(:buffer) do
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    end

    let(:link_renderer) { described_class.new(format: :bbcode, embeds: buffer, defer: %i[link]) }

    it "defers an attributed quote, recording the linkage and preserving the body" do
      raw =
        renderer.to_markdown('[quote="John, post:12, topic:34, username:john"]quoted body[/quote]')

      expect(buffer.quotes.size).to eq(1)
      descriptor = buffer.quotes.first
      # The Discourse attribution format carries coordinates: `post:` is a post
      # number, `topic:` a topic id.
      expect(descriptor[:quoted_post_id]).to be_nil
      expect(descriptor[:quoted_topic_id]).to eq(34)
      expect(descriptor[:quoted_post_number]).to eq(12)
      expect(descriptor[:quoted_username]).to eq("John")
      # The BBCode parser copies the leading token into both author and username,
      # so there's no distinct display name to keep.
      expect(descriptor[:quoted_name]).to be_nil

      # The token stands in for the opening tag; the body and closer remain.
      expect(raw).to include(descriptor[:placeholder])
      expect(raw).to include("quoted body")
      expect(raw).to include("[/quote]")
    end

    it "drops an attribution number too large for an id column" do
      # Meta really has a post titled like this; SQLite raises binding a bignum.
      raw = renderer.to_markdown('[quote="A, post:77777777777777777789999, topic:2"]q[/quote]')

      descriptor = buffer.quotes.first
      expect(descriptor[:quoted_post_number]).to be_nil
      expect(descriptor[:quoted_topic_id]).to eq(2)
      expect(descriptor[:quoted_username]).to eq("A")
      expect(raw).to include(descriptor[:placeholder])
    end

    it "renders an unattributed quote natively (nothing to remap)" do
      raw = renderer.to_markdown("[quote]just text[/quote]")

      expect(buffer).to be_empty
      expect(Migrations::Placeholder).not_to be_include(raw)
    end

    it "defers links only when asked via defer:" do
      raw = link_renderer.to_markdown("see [url=https://example.com/t/5]here[/url]")

      expect(buffer.links.size).to eq(1)
      descriptor = buffer.links.first
      expect(descriptor[:url]).to eq("https://example.com/t/5")
      expect(descriptor[:text]).to eq("here")
      expect(raw).to include(descriptor[:placeholder])
    end

    it "defers a link whose label is simple inline formatting" do
      raw = link_renderer.to_markdown("see [url=https://example.com/t/5][b]here[/b][/url]")

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to eq("**here**")
      expect(raw).to include(buffer.links.first[:placeholder])
    end

    it "defers a link whose label is inline code carrying a language" do
      # A language attribute alone never makes code a block, so code-with-a-
      # language still renders inline inside a link and stays deferrable — only
      # multi-line code is hoisted out.
      raw =
        link_renderer.to_markdown("see [url=https://example.com/t/5][code=ruby]x = 1[/code][/url]")

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to eq("`x = 1`")
      expect(raw).to include(buffer.links.first[:placeholder])
    end

    it "hoists multi-line code out of a link label instead of deferring it into text" do
      # The normalizer pulls multi-line code out of the inline container before
      # we render, so the link arrives with an empty (deferrable) label and the
      # code fence lands as a sibling block in the raw.
      raw = link_renderer.to_markdown("[url=https://example.com][code=ruby]a\nb[/code][/url]")

      expect(buffer.links).to contain_exactly(hash_including(url: "https://example.com", text: nil))
      expect(raw).to include(buffer.links.first[:placeholder])
      expect(raw).to include("```ruby\na\nb\n```")
    end

    it "defers a link whose quote label the normalizer hoisted out" do
      # Markbridge's normalizer pulls the quote out of the link before we
      # render, so the link arrives with an empty (hence deferrable) label
      # and the quote defers separately, as a sibling in the raw.
      raw =
        described_class.new(format: :bbcode, embeds: buffer, defer: %i[quote link]).to_markdown(
          '[url=https://example.com][quote="A, post:1, topic:2"]q[/quote][/url]',
        )

      expect(buffer.links).to contain_exactly(hash_including(url: "https://example.com", text: nil))
      expect(buffer.quotes.size).to eq(1)
      expect(raw).to include(buffer.links.first[:placeholder])
      expect(raw).to include(buffer.quotes.first[:placeholder])
    end

    it "renders a linked image natively instead of deferring the link" do
      raw =
        link_renderer.to_markdown(
          "[url=https://example.com][img]https://example.com/pic.png[/img][/url]",
        )

      # An image label isn't deferrable, so the link falls back to native
      # rendering and stays a clickable image — nothing is recorded.
      expect(buffer.links).to be_empty
      expect(raw).to eq("[![](https://example.com/pic.png)](https://example.com)")
    end

    it "unwraps a self-link even with link deferral on" do
      raw = link_renderer.to_markdown("[url=https://x/pic.png][img]https://x/pic.png[/img][/url]")

      # The self-link is dropped before rendering, so there is no link to defer;
      # the bare image renders inline.
      expect(buffer.links).to be_empty
      expect(raw).to eq("![](https://x/pic.png)")
    end

    it "records a bare URL's text as nil so the importer re-emits it bare" do
      link_renderer.to_markdown("see [url=https://example.com/t/5]https://example.com/t/5[/url]")

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to be_nil
    end

    it "records a text-less link's text as nil, not an empty string" do
      link_renderer.to_markdown("see [url=https://example.com/t/5][/url]")

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:text]).to be_nil
    end

    it "leaves links alone by default" do
      raw = renderer.to_markdown("see [url=https://example.com]here[/url]")

      expect(buffer.links).to be_empty
      expect(raw).to eq("see [here](https://example.com)")
    end

    # The contract: every token in the rendered raw maps to exactly one recorded
    # linkage descriptor.
    it "keeps placeholders and linkage rows one-to-one" do
      raw =
        described_class.new(format: :bbcode, embeds: buffer, defer: %i[quote link]).to_markdown(
          'a [quote="A, post:1, topic:2, username:a"]q[/quote] b ' \
            "[url=https://example.com/t/9]L[/url] c",
        )

      expect(Migrations::Placeholder.scan(raw)).to match_array(buffer.placeholders)
    end

    it "raises for an unknown defer kind at construction" do
      expect {
        described_class.new(format: :bbcode, embeds: buffer, defer: %i[bogus])
      }.to raise_error(ArgumentError, /Unknown defer kind :bogus; expected one of/)
    end
  end

  describe "#to_markdown reusing the built renderer across posts" do
    subject(:renderer) { described_class.new(format: :bbcode, embeds: buffer) }

    let(:buffer) do
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    end

    # Guards against reintroducing a per-post build: constructing Markbridge's
    # Discourse renderer costs about as much as converting a small post.
    it "converts every post through the one renderer built at construction" do
      built_renderers = []
      allow(Markbridge).to receive(:convert).and_wrap_original do |original, *args, **kwargs|
        built_renderers << kwargs[:renderer]
        original.call(*args, **kwargs)
      end

      renderer.to_markdown("a")
      renderer.to_markdown("b")

      expect(built_renderers.size).to eq(2)
      expect(built_renderers.first).to be(built_renderers.last)
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
    # extraction methods directly against the real AST nodes.
    let(:collector) do
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    end

    it "maps an Upload node's sha1 to upload_id" do
      _node_class, extract = described_class.embed_handlers.fetch(:upload)
      node = Markbridge::AST::Upload.new(sha1: "abc123", filename: "x.png")

      token = extract.call(collector, node, nil)

      expect(collector.uploads).to contain_exactly(
        { placeholder: token, upload_id: "abc123", original_markdown: nil },
      )
    end

    it "maps a Quote node's ids to quoted_post_id and quoted_user_id" do
      # BBCode can't carry them (phpBB-style id attribution arrives via the
      # TextFormatter parser), so exercise the method directly.
      _node_class, extract = described_class.embed_handlers.fetch(:quote)
      node = Markbridge::AST::Quote.new(username: "alice", post_id: 9001, user_id: 12)
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:with_parent).with(node).and_return(:child_context)
      allow(interface).to receive(:render_children).with(node, context: :child_context).and_return(
        "body",
      )

      extract.call(collector, node, interface)

      expect(collector.quotes).to contain_exactly(
        hash_including(quoted_post_id: 9001, quoted_user_id: 12, quoted_username: "alice"),
      )
    end

    it "records a display name that differs from the username" do
      _node_class, extract = described_class.embed_handlers.fetch(:quote)
      node = Markbridge::AST::Quote.new(author: "John Doe", username: "jdoe", user_id: 12)
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:with_parent).with(node).and_return(:child_context)
      allow(interface).to receive(:render_children).with(node, context: :child_context).and_return(
        "body",
      )

      extract.call(collector, node, interface)

      expect(collector.quotes).to contain_exactly(
        hash_including(quoted_username: "jdoe", quoted_name: "John Doe"),
      )
    end

    it "records no name when the author equals the username" do
      # The BBCode parser fills author and username with the same leading token.
      _node_class, extract = described_class.embed_handlers.fetch(:quote)
      node = Markbridge::AST::Quote.new(author: "john", username: "john", post_id: 9001)
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:with_parent).with(node).and_return(:child_context)
      allow(interface).to receive(:render_children).with(node, context: :child_context).and_return(
        "body",
      )

      extract.call(collector, node, interface)

      expect(collector.quotes).to contain_exactly(
        hash_including(quoted_username: "john", quoted_name: nil),
      )
    end

    it "defers a link whose label is single-line inline code" do
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      code = Markbridge::AST::Code.new << Markbridge::AST::Text.new("x")
      node << code
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_children).with(node).and_return("`x`")

      extract.call(collector, node, interface)

      expect(collector.links).to contain_exactly(hash_including(text: "`x`"))
    end

    it "falls back to native rendering for a label containing an upload" do
      # An upload inside a link keeps the label non-deferrable, so the link
      # renders natively rather than deferring a token into its `text` column.
      # An upload is the only deferrable embed that reaches this branch; a
      # mention never does, because the normalizer textifies it before the
      # :link handler sees the label.
      _node_class, extract = described_class.embed_handlers.fetch(:link)
      node = Markbridge::AST::Url.new(href: "https://example.com")
      node << Markbridge::AST::Upload.new(sha1: "abc123", filename: "x.png")
      interface = instance_double(Markbridge::Renderers::Discourse::RenderingInterface)
      allow(interface).to receive(:render_default).with(node).and_return("NATIVE")

      result = extract.call(collector, node, interface)

      expect(result).to eq("NATIVE")
      expect(collector.links).to be_empty
    end

    it "maps a Mention node's type and name" do
      _node_class, extract = described_class.embed_handlers.fetch(:mention)
      node = Markbridge::AST::Mention.new(name: "gerhard", type: :user)

      token = extract.call(collector, node, nil)

      expect(collector.mentions).to contain_exactly(
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
