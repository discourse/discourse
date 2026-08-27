# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  # An absolute URL on the source's own host whose path parses no route is still
  # rewritten: only its origin moves to the destination, the rest rides in the
  # suffix. A relative route-less URL stays literal (it's domain-free already).
  describe "SITE targets on a root install" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        markdown_engine:,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          "forum.example.com" => nil,
        },
      )
    end

    def link_for(raw)
      result = extract(raw)
      [buffer.links.first, result]
    end

    # A coordinate-shaped path that parses no route plausibly carries the OLD
    # site's ids — `/t//209` is an empty-slug spelling of topic 209 — so an
    # origin-only rewrite would point the new host at stale coordinates. Worse
    # than verbatim: the construct stays untouched and the body is reported.
    {
      "an empty topic slug" => "https://forum.example.com/t//209",
      "a junk topic id" => "https://forum.example.com/t/slug/5a",
      "an invalid user segment" => "https://forum.example.com/u/bob!!!",
      "a reserved multi-tag form" => "https://forum.example.com/tags/c/support/feature",
    }.each do |label, url|
      it "refuses #{label} instead of recording a SITE link" do
        raw = "This topic you've named [>>>>>](#{url}) doesn't load"

        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
        expect(extractor.engine_refusals).to eq(unanchored: 1)
      end
    end

    # The bare family segment is that family's index page — coordinate-free,
    # so it keeps the origin rewrite like any other site page.
    it "records a bare route-family index page as a SITE link" do
      link, = link_for("the user directory https://forum.example.com/u lists everyone")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/u")
    end

    it "does not read a family segment inside a longer word" do
      link, = link_for("[the team](https://forum.example.com/team)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/team")
    end

    it "records a real route-less page as a SITE link" do
      link, = link_for("[faq](https://forum.example.com/faq)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/faq")
    end

    it "keeps a query string in a SITE link's suffix" do
      link, = link_for("[search](https://forum.example.com/search?q=cats)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/search?q=cats")
    end

    it "keeps a fragment in a SITE link's suffix" do
      link, = link_for("[about](https://forum.example.com/about#team)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/about#team")
    end

    it "leaves a relative route-less URL literal" do
      raw = "[faq](/faq)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    # A bare URL on the source's own host is a link once cooked, whatever its
    # path, so it gets the same origin rewrite the bracketed form does. Before,
    # only a path carrying a route segment was recognized bare, and a plain
    # `/faq` in prose survived the migration pointing at the dead origin.
    {
      "a route-less page" => %w[https://forum.example.com/faq /faq],
      "a page mid-sentence" => ["see https://forum.example.com/faq here", "/faq"],
      "a query string" => %w[https://forum.example.com/search?q=cats /search?q=cats],
      "a fragment" => %w[https://forum.example.com/about#team /about#team],
      "a protocol-relative URL" => %w[//forum.example.com/faq /faq],
      "the site root" => %w[https://forum.example.com/ /],
      # Route-less on purpose: with no route segment the host is the only thing
      # that gets this body past the presence gate, so an upper-cased one only
      # works if that alternative is genuinely case-insensitive.
      "an upper-cased host and no route" => %w[HTTPS://FORUM.EXAMPLE.COM/faq /faq],
      "a mixed-case host and no route" => %w[https://FORUM.example.com/faq /faq],
    }.each do |label, (raw, suffix)|
      it "records a bare URL with #{label} as a SITE link" do
        link, = link_for(raw)

        expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: suffix)
      end
    end

    # A URL with no path is the forum's own front page, and its origin needs
    # rewriting like any other — otherwise it survives pointing at the site being
    # retired. A query or fragment with no path is the same page.
    {
      "the front page" => ["https://forum.example.com", nil],
      "the front page in link syntax" => ["[home](https://forum.example.com)", nil],
      "the front page mid-sentence" => ["see https://forum.example.com here", nil],
      "a query with no path" => %w[https://forum.example.com?ref=x&a=1 ?ref=x&a=1],
      "a fragment with no path" => %w[https://forum.example.com#top #top],
      "a protocol-relative front page" => ["//forum.example.com", nil],
      "a front page with a default port" => ["https://forum.example.com:443", nil],
    }.each do |label, (raw, suffix)|
      it "records #{label} as a SITE link" do
        link, = link_for(raw)

        expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: suffix)
      end
    end

    # `forum.example.com:3000` can be a different application than the forum
    # on `forum.example.com`, so a non-default port is part of the host
    # identity: it matches only a host configured with that port.
    it "leaves a front page on a non-default port literal" do
      link, result = link_for("https://forum.example.com:3000")

      expect(link).to be_nil
      expect(result).to eq("https://forum.example.com:3000")
    end

    it "records a front page on a non-default port when the host is configured with it" do
      extractor =
        described_class.new(
          embeds: buffer,
          markdown_engine:,
          mention_names:,
          hashtag_names:,
          internal_link_hosts: {
            "forum.example.com:3000" => nil,
          },
        )
      extractor.extract("https://forum.example.com:3000")

      expect(buffer.links.first).to include(target_type: enums::LinkTarget::SITE)
    end

    # The host stops at `?`, so the query is the path here and not part of a host
    # named `forum.example.com?ref=x`.
    it "keeps a sentence's punctuation out of a front-page URL" do
      link, result = link_for("see https://forum.example.com. Thanks")

      expect(link).to include(url: "https://forum.example.com", target_suffix: nil)
      expect(result).to eq("see #{link[:placeholder]}. Thanks")
    end

    it "still leaves a bare URL on a foreign host alone" do
      raw = "read https://other.example.org/faq here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "leaves a bare front-page URL on a foreign host alone" do
      raw = "read https://other.example.org here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    # Nothing in the body names the source's host or a route, so the post never
    # reaches the walk — the gate has to stay that selective.
    it "leaves a body of foreign URLs untouched" do
      raw = "See https://other.example.org/x and https://elsewhere.net/y please."

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end
  end
end
