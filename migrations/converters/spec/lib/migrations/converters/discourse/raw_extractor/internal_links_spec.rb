# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "internal links" do
    subject(:extractor) do
      described_class.new(embeds: buffer, internal_link_hosts: Set["forum.example.com"])
    end

    def link_for(raw)
      result = extract(raw)
      [buffer.links.first, result]
    end

    # A digit run past 18 characters overflows the signed 64-bit integers ids are
    # stored in — and names no real record: it's a numeric topic title, like the
    # meta.discourse.org post about exactly that, which crashed the insert.
    context "with a digit run too long to be an id" do
      it "leaves a numeric-title topic URL as literal text" do
        raw = "this one - https://forum.example.com/t/77777777777777777789999/ fails"

        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
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
        target_type: link_target::TOPIC,
        target_id: 123,
        target_suffix: nil,
      )
    end

    it "defers the id-only topic form" do
      link, = link_for("[x](/t/123)")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 123)
    end

    it "defers the slugless `/t/-/<id>` topic form" do
      link, = link_for("[x](/t/-/77)")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 77)
    end

    it "defers a post link by coordinates, recording no target_id" do
      link, = link_for("[x](/t/some-slug/123/4)")

      expect(link).to include(
        target_type: link_target::POST,
        target_id: nil,
        target_topic_id: 123,
        target_post_number: 4,
      )
    end

    it "defers the slugless post-coordinates form" do
      link, = link_for("[x](/t/12/3)")

      expect(link).to include(
        target_type: link_target::POST,
        target_topic_id: 12,
        target_post_number: 3,
      )
    end

    it "defers a `/p/<id>` post link" do
      link, = link_for("[x](/p/55)")

      expect(link).to include(target_type: link_target::POST, target_id: 55, target_topic_id: nil)
    end

    it "defers a user link by name, for both `/u/` and `/users/`" do
      expect(link_for("[x](/u/bob)").first).to include(
        target_type: link_target::USER,
        target_name: "bob",
      )

      buffer.clear
      expect(link_for("[x](/users/alice)").first).to include(
        target_type: link_target::USER,
        target_name: "alice",
      )
    end

    it "defers a category link by id when the path ends in a number" do
      link, = link_for("[x](/c/support/billing/6)")

      expect(link).to include(target_type: link_target::CATEGORY, target_id: 6, target_name: nil)
    end

    it "defers a legacy category link by its parent:child slug path" do
      link, = link_for("[x](/c/support/billing)")

      expect(link).to include(
        target_type: link_target::CATEGORY,
        target_id: nil,
        target_name: "support:billing",
      )
    end

    it "defers a tag link for both `/tag/` and `/tags/`" do
      expect(link_for("[x](/tag/release)").first).to include(
        target_type: link_target::TAG,
        target_name: "release",
      )

      buffer.clear
      expect(link_for("[x](/tags/release)").first).to include(
        target_type: link_target::TAG,
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

      expect(link).to include(target_type: link_target::GROUP, target_name: "team")
    end

    it "defers a badge link by id" do
      link, = link_for("[x](/badges/9/great)")

      expect(link).to include(target_type: link_target::BADGE, target_id: 9)
    end

    it "recognizes an absolute link on a configured host" do
      link, = link_for("read https://forum.example.com/t/slug/99 now")

      expect(link).to include(
        url: "https://forum.example.com/t/slug/99",
        target_type: link_target::TOPIC,
        target_id: 99,
      )
    end

    it "recognizes a protocol-relative link on a configured host" do
      link, = link_for("//forum.example.com/t/slug/99")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 99)
    end

    it "leaves an absolute link on a foreign host literal" do
      raw = "elsewhere https://other.example.com/t/slug/99 done"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "captures the link text of a markdown link" do
      link, result = link_for("[the topic](/t/slug/12)")

      expect(link).to include(text: "the topic", target_type: link_target::TOPIC, target_id: 12)
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

      expect(link).to include(target_type: link_target::TOPIC, target_id: 5)
      expect(result).to eq("(#{link[:placeholder]})")
    end

    it "rewrites an absolute self-host bare URL in prose" do
      link, result = link_for("look at https://forum.example.com/t/slug/5 please")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 5)
      expect(result).to eq("look at #{link[:placeholder]} please")
    end

    # Core linkifies a bare absolute URL after anything but an ASCII letter, digit
    # or `+` (see `internal_links_parity_spec.rb`), so a URL glued right after
    # prose punctuation is a link once cooked — the detector rewrites it too.
    it "rewrites a bare URL glued to preceding punctuation" do
      link, result = link_for("see,https://forum.example.com/t/slug/5 ok")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 5)
      expect(result).to eq("see,#{link[:placeholder]} ok")
    end

    # `_` is admitted too: markdown-it's inline linkify boundary rejects only
    # `[A-Za-z0-9.+-]`, and its core-ruler pass excludes `_` but the inline one
    # does not, so the union linkifies after `_`.
    it "rewrites a bare URL glued to a preceding underscore" do
      link, = link_for("x_https://forum.example.com/t/slug/5 ok")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 5)
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
        target_type: link_target::TOPIC,
        target_id: 5,
      )
      expect(result).to eq("[#{buffer.uploads.first[:placeholder]}](#{link[:placeholder]})")
    end

    it "rewrites the relative outer topic URL of a linked image" do
      sha1 = "0123456789abcdef0123456789abcdef01234567"
      result = extract("[![alt](upload://#{sha1}.png)](/t/slug/5)")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
      link = buffer.links.first
      expect(link).to include(url: "/t/slug/5", target_type: link_target::TOPIC, target_id: 5)
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
      plain_extractor = described_class.new(embeds: buffer)

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
        internal_link_hosts: Set["forum.example.com"],
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
        described_class.new(embeds: buffer, on_foreign_host: ->(host) { foreign_hosts << host })
      no_host.extract("read https://any.example.com/t/slug/99 now")

      expect(foreign_hosts).to eq(["any.example.com"])
    end

    it "is a no-op when no callback is given" do
      plain = described_class.new(embeds: buffer, internal_link_hosts: Set["forum.example.com"])

      expect(plain.extract("elsewhere https://old-forum.example.com/t/slug/99 done")).to eq(
        "elsewhere https://old-forum.example.com/t/slug/99 done",
      )
    end
  end
end
