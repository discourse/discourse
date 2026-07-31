# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "internal links" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
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

    # A digit run past 18 characters overflows the signed 64-bit integers ids are
    # stored in — and names no real record: it's a numeric topic title, a shape a
    # real forum turned out to have, which crashed the insert.
    context "with a digit run too long to be an id" do
      # A route-less numeric-title URL on the source's own host parses no id, so it
      # becomes a SITE link (origin rewrite). SITE stores no id, so the overflowing
      # digit run never reaches an integer bind — it rides along in the suffix.
      #
      # The trailing `/` belongs to the URL — core linkifies it into the href — so
      # it goes in the suffix too, rather than being left dangling after the
      # rewritten link.
      it "records a numeric-title topic URL as a SITE link, not an overflowing id" do
        raw = "this one - https://forum.example.com/t/77777777777777777789999/ fails"
        link, result = link_for(raw)

        expect(link).to include(
          target_type: enums::LinkTarget::SITE,
          target_id: nil,
          target_suffix: "/t/77777777777777777789999/",
        )
        expect(result).to eq("this one - #{link[:placeholder]} fails")
      end

      it "leaves an oversized /p/ id as literal text" do
        raw = "see /p/99999999999999999999999 there"

        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
      end

      it "reads an oversized trailing category segment as a slug, not an id" do
        link, _result = link_for("[cat](/c/77777777777777777789999)")

        expect(link).to include(target_id: nil, target_name: "77777777777777777789999")
      end

      it "still defers an 18-digit id" do
        link, _result = link_for("[topic](/t/123456789012345678)")

        expect(link).to include(target_id: 123_456_789_012_345_678)
      end

      it "degrades a quote with an oversized post: number to username-only" do
        extract(%([quote="bob, post:99999999999999999999, topic:5"]\nx\n[/quote]))

        expect(buffer.quotes.first).to include(
          quoted_username: "bob",
          quoted_post_number: nil,
          quoted_topic_id: nil,
        )
      end
    end

    it "defers a topic link with a slug and id" do
      link, = link_for("[the topic](/t/some-slug/123)")

      expect(link).to include(
        url: "/t/some-slug/123",
        target_type: enums::LinkTarget::TOPIC,
        target_id: 123,
        target_suffix: nil,
      )
    end

    # A destination can carry a title, padding, or angle brackets and still be a
    # link core resolves. Missing those left such a link pointing at the source
    # site after the migration. Each of these cooks to href="/t/slug/5".
    {
      "a title" => %([t](/t/slug/5 "title")),
      "a single-quoted title" => "[t](/t/slug/5 'title')",
      "a parenthesized title" => "[t](/t/slug/5 (title))",
      "padding" => "[t](  /t/slug/5  )",
      "angle brackets" => "[t](</t/slug/5>)",
      "angle brackets and a title" => %([t](</t/slug/5> "ti")),
      "an absolute URL and a title" => %([t](https://forum.example.com/t/slug/5 "ti")),
    }.each do |label, raw|
      it "defers a topic link written with #{label}" do
        link, = link_for(raw)

        expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
      end
    end

    # Core builds no link for either of these, so neither may be rewritten.
    ["[t](/t/slug/5 not-a-title)", %([t](/t/slug/5 "unclosed))].each do |raw|
      it "leaves #{raw} literal, since core makes no link of it" do
        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
      end
    end

    it "defers the id-only topic form" do
      link, = link_for("[x](/t/123)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 123)
    end

    it "defers the slugless `/t/-/<id>` topic form" do
      link, = link_for("[x](/t/-/77)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 77)
    end

    it "defers a post link by coordinates, recording no target_id" do
      link, = link_for("[x](/t/some-slug/123/4)")

      expect(link).to include(
        target_type: enums::LinkTarget::POST,
        target_id: nil,
        target_topic_id: 123,
        target_post_number: 4,
      )
    end

    it "defers the slugless post-coordinates form" do
      link, = link_for("[x](/t/12/3)")

      expect(link).to include(
        target_type: enums::LinkTarget::POST,
        target_topic_id: 12,
        target_post_number: 3,
      )
    end

    it "defers a `/p/<id>` post link" do
      link, = link_for("[x](/p/55)")

      expect(link).to include(
        target_type: enums::LinkTarget::POST,
        target_id: 55,
        target_topic_id: nil,
      )
    end

    it "defers a user link by name, for both `/u/` and `/users/`" do
      expect(link_for("[x](/u/bob)").first).to include(
        target_type: enums::LinkTarget::USER,
        target_name: "bob",
      )

      buffer.clear
      expect(link_for("[x](/users/alice)").first).to include(
        target_type: enums::LinkTarget::USER,
        target_name: "alice",
      )
    end

    it "defers a category link by id when the path ends in a number" do
      link, = link_for("[x](/c/support/billing/6)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: 6,
        target_name: nil,
      )
    end

    it "defers a category link with no slug at all" do
      link, = link_for("[x](/c/6)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: 6,
        target_name: nil,
      )
    end

    # `/c/<slug>/<id>/l/latest` is what a category's Latest tab links to, so the
    # route has to stop at the id and let the tail ride in the suffix — otherwise
    # the tail reads as more slug and the category never resolves.
    it "keeps a category's filter tail out of the slug path" do
      link, = link_for("[x](/c/support/6/l/latest)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: 6,
        target_name: nil,
        target_suffix: "/l/latest",
      )
    end

    it "keeps a filter tail out of a parent/child category path" do
      link, = link_for("[x](/c/parent/child/6/l/top)")

      expect(link).to include(target_id: 6, target_name: nil, target_suffix: "/l/top")
    end

    it "keeps a filter tail out of a slugless category link" do
      link, = link_for("[x](/c/6/l/latest)")

      expect(link).to include(target_id: 6, target_name: nil, target_suffix: "/l/latest")
    end

    it "reads the trailing id when a category slug is itself numeric" do
      link, = link_for("[x](/c/2015/6)")

      expect(link).to include(target_id: 6, target_name: nil)
    end

    it "keeps a category link's query string in the suffix" do
      link, = link_for("[x](/c/support/6?ascending=false)")

      expect(link).to include(target_id: 6, target_suffix: "?ascending=false")
    end

    it "defers a legacy category link by its parent:child slug path" do
      link, = link_for("[x](/c/support/billing)")

      expect(link).to include(
        target_type: enums::LinkTarget::CATEGORY,
        target_id: nil,
        target_name: "support:billing",
      )
    end

    it "defers a tag link for both `/tag/` and `/tags/`" do
      expect(link_for("[x](/tag/release)").first).to include(
        target_type: enums::LinkTarget::TAG,
        target_name: "release",
      )

      buffer.clear
      expect(link_for("[x](/tags/release)").first).to include(
        target_type: enums::LinkTarget::TAG,
        target_name: "release",
      )
    end

    it "leaves the `/tags/c/...` intersection form undetected" do
      raw = "browse [tags](/tags/c/food/wine) here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "defers a group link by name" do
      link, = link_for("[x](/g/team)")

      expect(link).to include(target_type: enums::LinkTarget::GROUP, target_name: "team")
    end

    it "defers a badge link by id" do
      link, = link_for("[x](/badges/9/great)")

      expect(link).to include(target_type: enums::LinkTarget::BADGE, target_id: 9)
    end

    it "recognizes an absolute link on a configured host" do
      link, = link_for("read https://forum.example.com/t/slug/99 now")

      expect(link).to include(
        url: "https://forum.example.com/t/slug/99",
        target_type: enums::LinkTarget::TOPIC,
        target_id: 99,
      )
    end

    it "recognizes a protocol-relative link on a configured host" do
      link, = link_for("//forum.example.com/t/slug/99")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 99)
    end

    # linkify-it reads the scheme case-insensitively, so core links these too;
    # older forums carried over uppercase schemes.
    %w[HTTPS Https HTTP hTTp].each do |scheme|
      it "recognizes a bare link with a #{scheme} scheme" do
        link, = link_for("read #{scheme}://forum.example.com/t/slug/99 now")

        expect(link).to include(
          url: "#{scheme}://forum.example.com/t/slug/99",
          target_type: enums::LinkTarget::TOPIC,
          target_id: 99,
        )
      end

      it "recognizes a markdown link with a #{scheme} scheme" do
        link, = link_for("[the topic](#{scheme}://forum.example.com/t/slug/99)")

        expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 99)
      end
    end

    it "recognizes an uppercase scheme with an uppercase host" do
      link, = link_for("read HTTPS://FORUM.EXAMPLE.COM/t/slug/99 now")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 99)
    end

    it "leaves an absolute link on a foreign host literal" do
      raw = "elsewhere https://other.example.com/t/slug/99 done"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "captures the link text of a markdown link" do
      link, result = link_for("[the topic](/t/slug/12)")

      expect(link).to include(
        text: "the topic",
        target_type: enums::LinkTarget::TOPIC,
        target_id: 12,
      )
      expect(result).to eq(link[:placeholder])
    end

    it "keeps a bare URL bare (no captured text)" do
      link, = link_for("https://forum.example.com/t/slug/12")

      expect(link[:text]).to be_nil
    end

    it "keeps trailing sentence punctuation out of a bare URL" do
      link, result = link_for("go to https://forum.example.com/t/slug/12. Thanks")

      expect(link[:url]).to eq("https://forum.example.com/t/slug/12")
      expect(result).to eq("go to #{link[:placeholder]}. Thanks")
    end

    it "captures a trailing sub-path as the suffix" do
      link, = link_for("[x](/u/bob/summary)")

      expect(link).to include(target_name: "bob", target_suffix: "/summary")
    end

    it "captures a query string as the suffix" do
      link, = link_for("[x](/users/alice?u=x)")

      expect(link).to include(target_name: "alice", target_suffix: "?u=x")
    end

    it "captures a fragment as the suffix" do
      link, = link_for("[x](/t/slug/12#reply)")

      expect(link).to include(target_id: 12, target_suffix: "#reply")
    end

    it "does not treat an image of an internal URL as a link" do
      raw = "![pic](/t/slug/1)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "leaves a relative URL inside a prose paren group literal" do
      raw = "(/t/slug/5)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "rewrites an absolute self-host URL inside a prose paren group" do
      link, result = link_for("(https://forum.example.com/t/slug/5)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
      expect(result).to eq("(#{link[:placeholder]})")
    end

    it "rewrites an absolute self-host bare URL in prose" do
      link, result = link_for("look at https://forum.example.com/t/slug/5 please")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
      expect(result).to eq("look at #{link[:placeholder]} please")
    end

    # Core linkifies a bare absolute URL after anything but an ASCII letter, digit
    # or `+` (see `internal_links_parity_spec.rb`), so a URL glued right after
    # prose punctuation is a link once cooked — the detector rewrites it too.
    it "rewrites a bare URL glued to preceding punctuation" do
      link, result = link_for("see,https://forum.example.com/t/slug/5 ok")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
      expect(result).to eq("see,#{link[:placeholder]} ok")
    end

    # `_` is admitted too: markdown-it's inline linkify boundary rejects only
    # `[A-Za-z0-9.+-]`, and its core-ruler pass excludes `_` but the inline one
    # does not, so the union linkifies after `_`.
    it "rewrites a bare URL glued to a preceding underscore" do
      link, = link_for("x_https://forum.example.com/t/slug/5 ok")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
    end

    # A URL glued right after an ASCII letter isn't linkified by core, and neither
    # is the `//host` inside it a standalone protocol-relative link (linkify-it's
    # `//` schema rejects the `://` tail), so the whole run stays literal.
    it "leaves a bare URL glued to a preceding word character literal" do
      raw = "sitehttps://forum.example.com/t/slug/5"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    # A `\` escapes the following character in markdown, so core forms no link;
    # the detector leaves the URL literal to match.
    it "leaves a backslash-escaped bare URL literal" do
      raw = "see \\https://forum.example.com/t/slug/5 ok"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "defers the inner image and rewrites the outer topic URL of a linked image" do
      sha1 = "0123456789abcdef0123456789abcdef01234567"
      inner = "https://forum.example.com/uploads/default/original/1X/#{sha1}.png"
      result = extract("[![alt](#{inner})](https://forum.example.com/t/some-topic/5)")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
      link = buffer.links.first
      expect(link).to include(
        url: "https://forum.example.com/t/some-topic/5",
        target_type: enums::LinkTarget::TOPIC,
        target_id: 5,
      )
      expect(result).to eq("[#{buffer.uploads.first[:placeholder]}](#{link[:placeholder]})")
    end

    it "rewrites the relative outer topic URL of a linked image" do
      sha1 = "0123456789abcdef0123456789abcdef01234567"
      result = extract("[![alt](upload://#{sha1}.png)](/t/slug/5)")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
      link = buffer.links.first
      expect(link).to include(url: "/t/slug/5", target_type: enums::LinkTarget::TOPIC, target_id: 5)
      expect(result).to eq("[#{buffer.uploads.first[:placeholder]}](#{link[:placeholder]})")
    end

    it "does not extract an internal link inside a fenced code block" do
      raw = <<~MD
        real [x](/t/slug/12)

        ```
        code [x](/t/slug/99) here
        ```
      MD

      result = extract(raw)

      expect(buffer.links.map { |l| l[:target_id] }).to eq([12])
      expect(result).to include("code [x](/t/slug/99) here")
    end

    it "detects a relative link only in link form when no host set is given" do
      plain_extractor = described_class.new(embeds: buffer, mention_names:, hashtag_names:)

      result = plain_extractor.extract("bare /t/slug/12 and linked [x](/t/slug/34)")

      # With no host set a relative link still qualifies, but only where it is a
      # real link: the bare one in prose stays literal, the link-form one defers.
      expect(buffer.links.map { |l| l[:url] }).to eq(["/t/slug/34"])
      expect(result).to include("bare /t/slug/12 and linked")
    end
  end

  describe "foreign-host internal-link signal" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          "forum.example.com" => nil,
        },
        on_foreign_host: ->(host) { foreign_hosts << host },
      )
    end

    let(:foreign_hosts) { [] }

    it "fires the callback for an absolute route-shaped link on an unconfigured host" do
      extract("elsewhere https://old-forum.example.com/t/slug/99 done")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
      expect(buffer.links).to be_empty
    end

    it "fires for a foreign-host markdown link too" do
      extract("[a topic](https://old-forum.example.com/t/slug/99)")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
    end

    it "drops the port before reporting the host" do
      extract("https://old-forum.example.com:8080/t/slug/99")

      expect(foreign_hosts).to eq(["old-forum.example.com"])
    end

    it "does not fire for a foreign host whose path is not an internal route" do
      extract("see https://old-forum.example.com/about/team here")

      expect(foreign_hosts).to be_empty
    end

    it "does not fire for a configured host" do
      extract("read https://forum.example.com/t/slug/99 now")

      expect(foreign_hosts).to be_empty
    end

    it "does not fire for a relative link" do
      extract("go to /t/slug/99")

      expect(foreign_hosts).to be_empty
    end

    it "treats every absolute route-shaped link as foreign when no host is configured" do
      no_host =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          on_foreign_host: ->(host) { foreign_hosts << host },
        )
      no_host.extract("read https://any.example.com/t/slug/99 now")

      expect(foreign_hosts).to eq(["any.example.com"])
    end

    it "is a no-op when no callback is given" do
      plain =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          internal_link_hosts: {
            "forum.example.com" => nil,
          },
        )

      expect(plain.extract("elsewhere https://old-forum.example.com/t/slug/99 done")).to eq(
        "elsewhere https://old-forum.example.com/t/slug/99 done",
      )
    end
  end

  # An absolute URL on the source's own host whose path parses no route is still
  # rewritten: only its origin moves to the destination, the rest rides in the
  # suffix. A relative route-less URL stays literal (it's domain-free already).
  describe "SITE targets on a root install" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
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

    it "records a route-shaped junk path as a SITE link, keeping the whole path in the suffix" do
      link, = link_for("read https://forum.example.com/t/slug/5a here")

      expect(link).to include(
        url: "https://forum.example.com/t/slug/5a",
        target_type: enums::LinkTarget::SITE,
        target_id: nil,
        target_suffix: "/t/slug/5a",
      )
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
      "a front page with a port" => ["https://forum.example.com:3000", nil],
    }.each do |label, (raw, suffix)|
      it "records #{label} as a SITE link" do
        link, = link_for(raw)

        expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: suffix)
      end
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

  describe "subdirectory installs" do
    subject(:extractor) do
      described_class.new(
        embeds: buffer,
        mention_names:,
        hashtag_names:,
        internal_link_hosts: {
          "www.example.com" => "/forum",
        },
        internal_link_base_prefix: "/forum",
      )
    end

    def link_for(raw)
      result = extract(raw)
      [buffer.links.first, result]
    end

    it "detects a subfolder absolute link, stripping the prefix before the route" do
      link, = link_for("[x](https://www.example.com/forum/t/slug/5)")

      expect(link).to include(
        target_type: enums::LinkTarget::TOPIC,
        target_id: 5,
        target_suffix: nil,
      )
    end

    # The prefix is what belongs to the forum, so `/forum` is the front page here.
    it "records the prefix itself as the front page" do
      link, = link_for("https://www.example.com/forum")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: nil)
    end

    # The host's own root is somebody else's app, not the forum, so rewriting its
    # origin would move a link that never pointed at us.
    %w[https://www.example.com https://www.example.com/ https://www.example.com?ref=x].each do |raw|
      it "leaves #{raw} alone, since only the prefix belongs to the forum" do
        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
      end
    end

    it "detects a subfolder absolute bare URL in prose" do
      link, = link_for("look https://www.example.com/forum/t/slug/5 now")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
    end

    it "detects a relative link carrying the base prefix" do
      link, = link_for("[x](/forum/t/slug/5)")

      expect(link).to include(target_type: enums::LinkTarget::TOPIC, target_id: 5)
    end

    it "records a route-less path inside the prefix as a SITE link with the rest" do
      link, = link_for("[faq](https://www.example.com/forum/faq)")

      expect(link).to include(target_type: enums::LinkTarget::SITE, target_suffix: "/faq")
    end

    it "leaves a sibling app's path on the same host literal" do
      raw = "[x](https://www.example.com/other-app/x)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "does not strip the prefix off a host path that only shares its leading text" do
      raw = "[x](https://www.example.com/forumxyz/t/slug/5)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "does not fire the foreign-host signal for a sibling app on a prefixed host" do
      foreign_hosts = []
      signalling =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          internal_link_hosts: {
            "www.example.com" => "/forum",
          },
          internal_link_base_prefix: "/forum",
          on_foreign_host: ->(host) { foreign_hosts << host },
        )

      signalling.extract("[x](https://www.example.com/other-app/t/slug/5)")

      expect(foreign_hosts).to be_empty
      expect(buffer.links).to be_empty
    end
  end
end
