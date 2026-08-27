# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  describe "internal links" do
    let(:internal_link_hosts) { { source_host => nil } }

    # A digit run past 18 characters overflows the signed 64-bit integers ids are
    # stored in — and names no real record: it's a numeric topic title, a shape a
    # real forum turned out to have, which crashed the insert.
    context "with a digit run too long to be an id" do
      # A route-less numeric-title URL parses no id, and nothing can tell a
      # slug-only title apart from malformed coordinates without guessing — a
      # `/t/…` path that parses no route refuses rather than host-swapping
      # (see `RouteParser.coordinate_shaped?`). No row is created, so the
      # overflowing digit run still never reaches an integer bind.
      it "refuses a numeric-title topic URL rather than guessing at its shape" do
        raw = "this one - https://forum.example.com/t/77777777777777777789999/ fails"

        expect(extract(raw)).to eq(raw)
        expect(buffer.links).to be_empty
        expect(extractor.engine_refusals).to eq(unanchored: 1)
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

    # Core routes `/t/<slug>` to the topic carrying that slug, so the slug is
    # the coordinate; resolution looks it up and restores the source unless
    # exactly one topic matches.
    context "with a slug-only topic link" do
      it "defers the topic by its slug" do
        link, = link_for("[topic](/t/how-to-fix-it)")

        expect(link).to include(
          target_type: enums::LinkTarget::TOPIC,
          target_id: nil,
          target_name: "how-to-fix-it",
          target_suffix: nil,
        )
      end

      it "keeps the query tail as suffix" do
        link, = link_for("see https://forum.example.com/t/how-to-fix-it?page=2 there")

        expect(link).to include(target_name: "how-to-fix-it", target_suffix: "?page=2")
      end
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

    # Categories nest three deep, so the slug path has to survive a third level
    # with the tab tail still coming off it.
    {
      "no tail" => ["/c/gp/parent/child", "gp:parent:child", nil],
      "a filter tail" => %w[/c/gp/parent/child/l/latest gp:parent:child /l/latest],
      "a period tail" => %w[/c/gp/parent/child/l/top/weekly gp:parent:child /l/top/weekly],
      "a /none tail" => %w[/c/gp/parent/child/none gp:parent:child /none],
    }.each do |label, (path, name, suffix)|
      it "reads a three-level category slug path with #{label}" do
        link, = link_for("[x](#{path})")

        expect(link).to include(target_name: name, target_id: nil, target_suffix: suffix)
      end
    end

    it "reads a three-level category by id, with the tail in the suffix" do
      link, = link_for("[x](/c/gp/parent/child/6/l/latest)")

      expect(link).to include(target_id: 6, target_name: nil, target_suffix: "/l/latest")
    end

    # A tag name is a single segment, so anything after it is already suffix —
    # the tab tails that needed guarding on the category routes cost nothing here.
    {
      "a filter tail" => %w[/tag/release/l/latest /l/latest],
      "a period tail" => %w[/tags/release/l/top/weekly /l/top/weekly],
      "a /none tail" => %w[/tag/release/none /none],
    }.each do |label, (path, suffix)|
      it "keeps #{label} out of a tag name" do
        link, = link_for("[x](#{path})")

        expect(link).to include(
          target_type: enums::LinkTarget::TAG,
          target_name: "release",
          target_suffix: suffix,
        )
      end
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

    # Core routes every tab (`/l/<filter>`, `/none`, `/all`, `/subcategories`)
    # inside `c/*category_slug_path_with_id`, so Rails strips the tail before
    # `Category.find_by_slug_path_with_id` sees the glob. The id-less form has to
    # stop there too, or the tab name folds into the slug and names no category.
    describe "filter tails on the legacy id-less form" do
      {
        "/c/support/l/latest" => %w[support /l/latest],
        "/c/support/l/top/weekly" => %w[support /l/top/weekly],
        "/c/parent/child/l/hot" => %w[parent:child /l/hot],
        "/c/support/none" => %w[support /none],
        "/c/support/all" => %w[support /all],
        "/c/support/subcategories" => %w[support /subcategories],
      }.each do |url, (name, suffix)|
        it "reads #{url} as #{name.inspect} with the tail in the suffix" do
          link, = link_for("[x](#{url})")

          expect(link).to include(
            target_type: enums::LinkTarget::CATEGORY,
            target_id: nil,
            target_name: name,
            target_suffix: suffix,
          )
        end
      end

      # Only `/l/<filter>` is a tab; a bare segment that happens to spell a filter
      # is an ordinary subcategory slug, so it stays part of the path.
      it "keeps a subcategory slug that merely spells a filter in the path" do
        link, = link_for("[x](/c/support/latest)")

        expect(link).to include(target_name: "support:latest", target_suffix: nil)
      end

      # `/c/<slug>/none/<tag-slug>/<tag-id>` is a category+tag intersection. The
      # trailing number is the tag's id, so the slug path must not run through the
      # tail and read it as the category's.
      it "does not read an intersection URL's tag id as the category id" do
        link, = link_for("[x](/c/support/none/bug/12)")

        expect(link).to include(
          target_type: enums::LinkTarget::CATEGORY,
          target_id: nil,
          target_name: "support",
          target_suffix: "/none/bug/12",
        )
      end
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

    # The multi-tag routes name several records at once, so the reference
    # carries the category the way plain category links do plus the tag path in
    # `target_tag_path` — the importer rebuilds the route only when every
    # coordinate maps.
    describe "multi-tag routes" do
      it "defers a category+tag link with the category addressed by id" do
        link, = link_for("[x](/tags/c/plugin/22/official)")

        expect(link).to include(
          target_type: enums::LinkTarget::CATEGORY_TAG,
          target_id: 22,
          target_name: nil,
          target_tag_path: "official",
          target_suffix: nil,
        )
      end

      it "defers the legacy id-less form with the joined slug path" do
        link, = link_for("[x](/tags/c/food/wine)")

        expect(link).to include(
          target_type: enums::LinkTarget::CATEGORY_TAG,
          target_id: nil,
          target_name: "food",
          target_tag_path: "wine",
        )
      end

      it "reads a multi-level slug path the way category links do" do
        link, = link_for("[x](/tags/c/howto/devs/import)")

        expect(link).to include(target_name: "howto:devs", target_tag_path: "import")
      end

      it "keeps the `none`/`all` subcategory filter in the tag path" do
        link, = link_for("[x](/tags/c/theme/61/none/extra)")

        expect(link).to include(target_id: 61, target_tag_path: "none/extra")
      end

      it "leaves a list-filter tab and the query in the suffix" do
        link, = link_for("[x](/tags/c/plugin/22/official/l/top?period=yearly)")

        expect(link).to include(
          target_id: 22,
          target_tag_path: "official",
          target_suffix: "/l/top?period=yearly",
        )
      end

      it "defers an intersection link with every tag in the path" do
        link, = link_for("[x](/tags/intersection/food/wine/cheese)")

        expect(link).to include(
          target_type: enums::LinkTarget::TAG_INTERSECTION,
          target_id: nil,
          target_name: nil,
          target_tag_path: "food/wine/cheese",
        )
      end
    end

    it "still reads a bare /tags/intersection as a tag with that name" do
      link, = link_for("[x](/tags/intersection)")

      expect(link).to include(target_type: enums::LinkTarget::TAG, target_name: "intersection")
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

    # Core allows one level of balanced brackets in link text, so a
    # citation-style link is still a link and must be rewritten.
    it "captures link text holding a balanced bracket pair" do
      link, result = link_for("[see [1]](/t/slug/12)")

      expect(link).to include(text: "see [1]", target_id: 12)
      expect(result).to eq(link[:placeholder])
    end

    it "captures link text that is only a bracket pair" do
      link, = link_for("[[1]](/t/slug/12)")

      expect(link).to include(text: "[1]", target_id: 12)
    end

    # `[](url)` is valid CommonMark that core renders as a link with no text —
    # a shape real corpora carry (pasted HTML digests). The empty label
    # records no label span (there is nothing to rewrite in it), and the
    # destination span points at the url as usual.
    it "defers a link with an empty label" do
      link, result = link_for("[](https://forum.example.com/t/slug/12)")

      expect(link).to include(
        text: "",
        target_type: enums::LinkTarget::TOPIC,
        target_id: 12,
        url_offset: 3,
        label_url_offset: nil,
        original_markdown: "[](https://forum.example.com/t/slug/12)",
      )
      expect(result).to eq(link[:placeholder])
      expect(extractor.engine_refusals).to be_empty
    end

    # Links don't nest in core: the inner `[…](…)` wins and the outer bracket
    # stays literal, so the outer text must not match around it.
    it "defers the inner link when the text holds a nested link" do
      link, = link_for("[see [1](/t/nine/9)](/t/slug/12)")

      expect(link).to include(text: "1", target_id: 9)
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
      plain_extractor =
        described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:)

      result = plain_extractor.extract("bare /t/slug/12 and linked [x](/t/slug/34)")

      # With no host set a relative link still qualifies, but only where it is a
      # real link: the bare one in prose stays literal, the link-form one defers.
      expect(buffer.links.map { |l| l[:url] }).to eq(["/t/slug/34"])
      expect(result).to include("bare /t/slug/12 and linked")
    end
  end
end
