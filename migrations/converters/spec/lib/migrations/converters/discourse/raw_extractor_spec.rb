# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  subject(:extractor) { described_class.new }

  let(:link_target) { Migrations::Database::IntermediateDB::Enums::LinkTarget }
  let(:hashtag_type) { Migrations::Database::IntermediateDB::Enums::HashtagType }
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }

  let(:buffer) do
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  end

  def extract(raw, topic_id: nil)
    extractor.extract(raw, embeds: buffer, topic_id:)
  end

  it "returns nil for a nil body" do
    expect(extract(nil)).to be_nil
  end

  it "leaves a body with no embeds untouched" do
    raw = "Just some **plain** text with a (paren) and a / slash."

    expect(extract(raw)).to eq(raw)
    expect(buffer).to be_empty
  end

  describe "uploads" do
    it "defers an image upload, recording the sha1" do
      result = extract("before ![alt|690x388](upload://abc123XYZ.png) after")

      expect(buffer.uploads.size).to eq(1)
      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq("abc123XYZ")
      expect(result).to eq("before #{upload[:placeholder]} after")
    end

    it "defers an attachment upload" do
      extract("[report.pdf|attachment](upload://Zm9vYmFy.pdf)")

      expect(buffer.uploads.first[:upload_id]).to eq("Zm9vYmFy")
    end

    it "records no original_markdown for an upload:// reference" do
      extract("![alt](upload://abc123.png)")

      expect(buffer.uploads.first[:original_markdown]).to be_nil
    end
  end

  describe "full-URL uploads" do
    let(:sha1) { "0123456789abcdef0123456789abcdef01234567" }

    it "defers an image referenced by a root-relative upload URL" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("before ![pic](#{url}) after")

      upload = buffer.uploads.first
      expect(upload[:upload_id]).to eq(sha1)
      expect(upload[:original_markdown]).to eq("![pic](#{url})")
      expect(result).to eq("before #{upload[:placeholder]} after")
    end

    it "defers a markdown link to an absolute upload URL" do
      url = "https://forum.example.com/uploads/default/original/2X/a/ab/#{sha1}.pdf"
      extract("[report](#{url})")

      expect(buffer.uploads.first).to include(
        upload_id: sha1,
        original_markdown: "[report](#{url})",
      )
    end

    it "defers a bare, whitespace-delimited upload URL" do
      url = "https://cdn.example.com/uploads/default/original/1X/#{sha1}.png"
      result = extract("see #{url} thanks")

      upload = buffer.uploads.first
      expect(upload).to include(upload_id: sha1, original_markdown: url)
      expect(result).to eq("see #{upload[:placeholder]} thanks")
    end

    it "reads the sha1 from an optimized image variant" do
      url = "/uploads/default/optimized/2X/a/ab/#{sha1}_2_690x388.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes a secure-uploads URL" do
      url = "/secure-uploads/original/2X/a/ab/#{sha1}.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "recognizes a protocol-relative upload URL" do
      url = "//cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
      extract("![x](#{url})")

      expect(buffer.uploads.first[:upload_id]).to eq(sha1)
    end

    it "keeps a bare URL's trailing sentence punctuation out of the match" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      result = extract("look at #{url}.")

      expect(buffer.uploads.first[:original_markdown]).to eq(url)
      expect(result).to eq("look at #{buffer.uploads.first[:placeholder]}.")
    end

    it "ignores a non-upload URL" do
      raw = "![photo](https://example.com/images/photo.png) and https://example.com/page"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "ignores an uploads URL whose basename is not a 40-hex sha1" do
      raw = "![x](/uploads/default/original/2X/a/ab/deadbeef.png)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract a full-URL upload inside a fenced code block" do
      url = "/uploads/default/original/2X/a/ab/#{sha1}.png"
      raw = <<~MD
        real ![pic](#{url})

        ```
        code ![pic](#{url}) and bare #{url}
        ```
      MD

      result = extract(raw)

      expect(buffer.uploads.size).to eq(1)
      expect(result).to include("code ![pic](#{url}) and bare #{url}")
    end
  end

  describe "quotes" do
    it "records the source coordinates as integers and never a post_id" do
      result = extract(%([quote="bob, post:12, topic:5"]\nquoted body\n[/quote]))

      expect(buffer.quotes.size).to eq(1)
      quote = buffer.quotes.first
      expect(quote).to include(
        quoted_username: "bob",
        quoted_topic_id: 5,
        quoted_post_number: 12,
        quoted_post_id: nil,
      )
      expect(result).to eq("#{quote[:placeholder]}\nquoted body\n[/quote]")
    end

    it "uses the explicit username: attribute and keeps the display name" do
      extract(%([quote="Bob Jones, post:1, topic:2, username:bjones"]hi[/quote]))

      expect(buffer.quotes.first).to include(
        quoted_username: "bjones",
        quoted_name: "Bob Jones",
        quoted_topic_id: 2,
        quoted_post_number: 1,
      )
    end

    it "records no name for a bare leading token that IS the username" do
      # Without an explicit username:, the leading token is the username itself
      # (Discourse omits username: when the display name equals it).
      extract(%([quote="jane, post:1"]hi[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "records no name when the display name equals the explicit username" do
      extract(%([quote="jane, post:1, topic:2, username:jane"]hi[/quote]))

      expect(buffer.quotes.first).to include(quoted_username: "jane", quoted_name: nil)
    end

    it "fills the containing topic id when the attribution names a post but no topic" do
      extract(%([quote="bob, post:12"]body[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(quoted_topic_id: 77, quoted_post_number: 12)
    end

    it "records no coordinates for a username-only quote" do
      extract(%([quote="alice"]hello[/quote]), topic_id: 77)

      expect(buffer.quotes.first).to include(
        quoted_username: "alice",
        quoted_topic_id: nil,
        quoted_post_number: nil,
        quoted_post_id: nil,
      )
    end

    it "leaves an unattributed quote alone" do
      raw = "[quote]anonymous[/quote]"

      expect(extract(raw)).to eq(raw)
      expect(buffer.quotes).to be_empty
    end
  end

  describe "mentions" do
    it "defers a mention, recording the username and preserving surrounding text" do
      result = extract("hey @alice, welcome")

      expect(buffer.mentions.size).to eq(1)
      mention = buffer.mentions.first
      expect(mention).to include(mention_type: mention_type::USER, name: "alice")
      expect(result).to eq("hey #{mention[:placeholder]}, welcome")
    end

    it "defers a mention at the very start of the body" do
      result = extract("@bob hi")

      expect(buffer.mentions.first[:name]).to eq("bob")
      expect(result).to eq("#{buffer.mentions.first[:placeholder]} hi")
    end

    it "does not treat an e-mail address as a mention" do
      raw = "email me at bob@example.com please"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "captures a username containing a dot" do
      result = extract("hi @john.doe there")

      expect(buffer.mentions.first[:name]).to eq("john.doe")
      expect(result).to eq("hi #{buffer.mentions.first[:placeholder]} there")
    end

    it "keeps a trailing sentence period out of the name" do
      result = extract("thanks @bob.")

      expect(buffer.mentions.first[:name]).to eq("bob")
      expect(result).to eq("thanks #{buffer.mentions.first[:placeholder]}.")
    end

    it "captures a username with a hyphen" do
      extract("cc @some-user please")

      expect(buffer.mentions.first[:name]).to eq("some-user")
    end

    it "classifies mention types via the injected resolver" do
      resolver =
        Migrations::Converters::Discourse::MentionResolver.new(
          here_mention: "here",
          group_names: %w[admins],
        )
      extractor = described_class.new(mention_resolver: resolver)

      extractor.extract("@gerhard @admins @here all there", embeds: buffer)

      expect(buffer.mentions.map { |m| [m[:name], m[:mention_type]] }).to eq(
        [
          ["gerhard", mention_type::USER],
          ["admins", mention_type::GROUP],
          ["here", mention_type::HERE],
        ],
      )
    end
  end

  describe "mentions with an existence gate" do
    subject(:extractor) do
      described_class.new(
        mention_names:
          Migrations::SortedStringSet.new(
            %w[alice bob john.doe staff here all café_team].map do |name|
              Migrations::NameNormalizer.normalize(name)
            end,
          ),
      )
    end

    it "defers a mention whose username is in the set" do
      result = extract("hey @alice there")

      expect(buffer.mentions.first[:name]).to eq("alice")
      expect(result).to eq("hey #{buffer.mentions.first[:placeholder]} there")
    end

    it "leaves an @word that names nothing on the source as literal text" do
      raw = "meet at @3pm please"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "defers a group mention in the set" do
      extract("cc @staff now")

      expect(buffer.mentions.first[:name]).to eq("staff")
    end

    it "defers the here and all names in the set" do
      extract("@here and @all please")

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[here all])
    end

    it "matches the set case-insensitively" do
      extract("ping @Bob today")

      expect(buffer.mentions.first[:name]).to eq("Bob")
    end

    it "matches a Unicode name in the set" do
      extract("cc @café_team here")

      expect(buffer.mentions.first[:name]).to eq("café_team")
    end

    it "defers a dotted username in the set" do
      extract("hi @john.doe there")

      expect(buffer.mentions.first[:name]).to eq("john.doe")
    end

    it "defers every parsed @word when no gate is given" do
      ungated = described_class.new
      ungated.extract("meet at @3pm please", embeds: buffer)

      expect(buffer.mentions.first[:name]).to eq("3pm")
    end
  end

  describe "hashtags" do
    it "defers a bare hashtag, recording the name and leaving the type for import" do
      result = extract("see #announcements please")

      expect(buffer.hashtags.size).to eq(1)
      hashtag = buffer.hashtags.first
      expect(hashtag).to include(name: "announcements", hashtag_type: nil, target_id: nil)
      expect(result).to eq("see #{hashtag[:placeholder]} please")
    end

    it "keeps a category's parent:child separator in the name" do
      extract("in #support:billing here")

      expect(buffer.hashtags.first).to include(name: "support:billing", hashtag_type: nil)
    end

    it "records a forced ::tag suffix as the tag type, dropping the suffix from the name" do
      extract("tagged #release::tag today")

      expect(buffer.hashtags.first).to include(name: "release", hashtag_type: hashtag_type::TAG)
    end

    it "records a forced ::category suffix case-insensitively" do
      extract("filed #Support::CATEGORY now")

      expect(buffer.hashtags.first).to include(
        name: "Support",
        hashtag_type: hashtag_type::CATEGORY,
      )
    end

    it "defers a hashtag right after an opening paren" do
      result = extract("(#news)")

      expect(buffer.hashtags.first[:name]).to eq("news")
      expect(result).to eq("(#{buffer.hashtags.first[:placeholder]})")
    end

    it "does not treat a markdown heading as a hashtag" do
      raw = "# Heading\n\nbody"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "does not treat a mid-word # as a hashtag" do
      raw = "issue no#42 was closed"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "leaves an unknown ::channel-style suffix as literal text" do
      raw = "chat in #general::channel today"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "does not extract a hashtag inside a fenced code block" do
      raw = <<~MD
        real #announcements

        ```
        not a #hashtag here
        ```
      MD

      result = extract(raw)

      expect(buffer.hashtags.map { |h| h[:name] }).to eq(%w[announcements])
      expect(result).to include("not a #hashtag here")
    end
  end

  describe "hashtags with an existence gate" do
    subject(:extractor) do
      described_class.new(
        hashtag_names: Migrations::SortedStringSet.new(%w[announcements support:billing]),
      )
    end

    it "defers a hashtag whose name is in the set" do
      result = extract("see #announcements please")

      expect(buffer.hashtags.first[:name]).to eq("announcements")
      expect(result).to eq("see #{buffer.hashtags.first[:placeholder]} please")
    end

    it "leaves a hashtag that names nothing on the source as literal text" do
      raw = "tracked in PR #123 and channel #general"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "defers a parent:child category path in the set" do
      extract("filed under #support:billing today")

      expect(buffer.hashtags.first[:name]).to eq("support:billing")
    end

    it "matches the set case- and Unicode-insensitively" do
      extract("see #Announcements please")

      expect(buffer.hashtags.first[:name]).to eq("Announcements")
    end

    it "leaves a forced suffix on an unknown name as literal text" do
      raw = "tagged #unknown::tag today"

      expect(extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    it "gates a forced suffix on the name, deferring a known one" do
      extract("in #announcements::category now")

      expect(buffer.hashtags.first).to include(
        name: "announcements",
        hashtag_type: hashtag_type::CATEGORY,
      )
    end
  end

  describe "custom emoji" do
    subject(:extractor) { described_class.new(custom_emoji_names: %w[parrot +1]) }

    it "defers a shortcode that names a source custom emoji" do
      result = extract("nice :parrot: work")

      expect(buffer.emojis.size).to eq(1)
      emoji = buffer.emojis.first
      expect(emoji[:name]).to eq("parrot")
      expect(result).to eq("nice #{emoji[:placeholder]} work")
    end

    it "leaves a standard emoji shortcode as plain text" do
      raw = "hello :smile: there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "does not treat a clock time as an emoji" do
      raw = "meet at 10:30:45 sharp"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "does not treat a shortcode glued to a word as an emoji" do
      raw = "path:parrot: here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end

    it "defers a shortcode right after an opening paren" do
      extract("(:parrot:)")

      expect(buffer.emojis.first[:name]).to eq("parrot")
    end

    it "defers every shortcode of an adjacent chain" do
      result = extract("well done :parrot::+1:")

      expect(buffer.emojis.map { |emoji| emoji[:name] }).to eq(%w[parrot +1])
      placeholders = buffer.emojis.map { |emoji| emoji[:placeholder] }
      expect(result).to eq("well done #{placeholders.join}")
    end

    it "defers a custom emoji chained onto a standard one" do
      result = extract("thanks :smile::parrot:")

      expect(buffer.emojis.map { |emoji| emoji[:name] }).to eq(%w[parrot])
      expect(result).to eq("thanks :smile:#{buffer.emojis.first[:placeholder]}")
    end

    it "does not extract a custom emoji inside a fenced code block" do
      raw = <<~MD
        real :parrot:

        ```
        code :parrot: here
        ```
      MD

      result = extract(raw)

      expect(buffer.emojis.size).to eq(1)
      expect(result).to include("code :parrot: here")
    end

    it "skips emoji detection entirely when the source has no custom emoji" do
      plain_extractor = described_class.new
      raw = "a :parrot: and :smile:"

      expect(plain_extractor.extract(raw, embeds: buffer)).to eq(raw)
      expect(buffer.emojis).to be_empty
    end
  end

  describe "internal links" do
    subject(:extractor) { described_class.new(internal_link_hosts: Set["forum.example.com"]) }

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
        link, _result = link_for("in /c/77777777777777777789999 maybe")

        expect(link).to include(target_id: nil, target_name: "77777777777777777789999")
      end

      it "still defers an 18-digit id" do
        link, _result = link_for("see /t/123456789012345678 here")

        expect(link).to include(target_id: 123_456_789_012_345_678)
      end

      it "degrades a quote with an oversized post: number to username-only" do
        extract(%([quote="bob, post:99999999999999999999, topic:5"]x[/quote]))

        expect(buffer.quotes.first).to include(
          quoted_username: "bob",
          quoted_post_number: nil,
          quoted_topic_id: nil,
        )
      end
    end

    it "defers a topic link with a slug and id" do
      link, result = link_for("see /t/some-slug/123 here")

      expect(link).to include(
        url: "/t/some-slug/123",
        text: nil,
        target_type: link_target::TOPIC,
        target_id: 123,
        target_suffix: nil,
      )
      expect(result).to eq("see #{link[:placeholder]} here")
    end

    it "defers the id-only topic form" do
      link, = link_for("/t/123")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 123)
    end

    it "defers the slugless `/t/-/<id>` topic form" do
      link, = link_for("/t/-/77")

      expect(link).to include(target_type: link_target::TOPIC, target_id: 77)
    end

    it "defers a post link by coordinates, recording no target_id" do
      link, = link_for("/t/some-slug/123/4")

      expect(link).to include(
        target_type: link_target::POST,
        target_id: nil,
        target_topic_id: 123,
        target_post_number: 4,
      )
    end

    it "defers the slugless post-coordinates form" do
      link, = link_for("/t/12/3")

      expect(link).to include(
        target_type: link_target::POST,
        target_topic_id: 12,
        target_post_number: 3,
      )
    end

    it "defers a `/p/<id>` post link" do
      link, = link_for("/p/55")

      expect(link).to include(target_type: link_target::POST, target_id: 55, target_topic_id: nil)
    end

    it "defers a user link by name, for both `/u/` and `/users/`" do
      expect(link_for("/u/bob").first).to include(
        target_type: link_target::USER,
        target_name: "bob",
      )

      buffer.clear
      expect(link_for("/users/alice").first).to include(
        target_type: link_target::USER,
        target_name: "alice",
      )
    end

    it "defers a category link by id when the path ends in a number" do
      link, = link_for("/c/support/billing/6")

      expect(link).to include(target_type: link_target::CATEGORY, target_id: 6, target_name: nil)
    end

    it "defers a legacy category link by its parent:child slug path" do
      link, = link_for("/c/support/billing")

      expect(link).to include(
        target_type: link_target::CATEGORY,
        target_id: nil,
        target_name: "support:billing",
      )
    end

    it "defers a tag link for both `/tag/` and `/tags/`" do
      expect(link_for("/tag/release").first).to include(
        target_type: link_target::TAG,
        target_name: "release",
      )

      buffer.clear
      expect(link_for("/tags/release").first).to include(
        target_type: link_target::TAG,
        target_name: "release",
      )
    end

    it "leaves the `/tags/c/...` intersection form undetected" do
      raw = "browse /tags/c/food/wine here"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "defers a group link by name" do
      link, = link_for("/g/team")

      expect(link).to include(target_type: link_target::GROUP, target_name: "team")
    end

    it "defers a badge link by id" do
      link, = link_for("/badges/9/great")

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
      link, = link_for("/t/slug/12")

      expect(link[:text]).to be_nil
    end

    it "keeps trailing sentence punctuation out of a bare URL" do
      link, result = link_for("go to /t/slug/12. Thanks")

      expect(link[:url]).to eq("/t/slug/12")
      expect(result).to eq("go to #{link[:placeholder]}. Thanks")
    end

    it "captures a trailing sub-path as the suffix" do
      link, = link_for("/u/bob/summary")

      expect(link).to include(target_name: "bob", target_suffix: "/summary")
    end

    it "captures a query string as the suffix" do
      link, = link_for("/users/alice?u=x")

      expect(link).to include(target_name: "alice", target_suffix: "?u=x")
    end

    it "captures a fragment as the suffix" do
      link, = link_for("/t/slug/12#reply")

      expect(link).to include(target_id: 12, target_suffix: "#reply")
    end

    it "does not treat an image of an internal URL as a link" do
      raw = "![pic](/t/slug/1)"

      expect(extract(raw)).to eq(raw)
      expect(buffer.links).to be_empty
    end

    it "does not extract an internal link inside a fenced code block" do
      raw = <<~MD
        real /t/slug/12

        ```
        code /t/slug/99 here
        ```
      MD

      result = extract(raw)

      expect(buffer.links.map { |l| l[:target_id] }).to eq([12])
      expect(result).to include("code /t/slug/99 here")
    end

    it "recognizes only relative links when no host set is given" do
      plain_extractor = described_class.new

      plain_extractor.extract(
        "rel /t/slug/12 and abs https://forum.example.com/t/slug/99",
        embeds: buffer,
      )

      expect(buffer.links.map { |l| l[:url] }).to eq(["/t/slug/12"])
    end
  end

  describe "foreign-host internal-link signal" do
    subject(:extractor) do
      described_class.new(
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
      no_host = described_class.new(on_foreign_host: ->(host) { foreign_hosts << host })
      no_host.extract("read https://any.example.com/t/slug/99 now", embeds: buffer)

      expect(foreign_hosts).to eq(["any.example.com"])
    end

    it "is a no-op when no callback is given" do
      plain = described_class.new(internal_link_hosts: Set["forum.example.com"])

      expect(
        plain.extract("elsewhere https://old-forum.example.com/t/slug/99 done", embeds: buffer),
      ).to eq("elsewhere https://old-forum.example.com/t/slug/99 done")
    end
  end

  # The whole reason to wrap Markbridge's scanner: things that only look like
  # embeds inside code must be left alone.
  describe "code blocks" do
    it "does not extract from a fenced code block" do
      raw = <<~MD
        real @alice here

        ```
        not a @mention and ![x](upload://nope.png) and [quote="ghost"]q[/quote]
        ```
      MD

      result = extract(raw)

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(buffer.uploads).to be_empty
      expect(buffer.quotes).to be_empty
      expect(result).to include("not a @mention and ![x](upload://nope.png)")
    end

    it "does not extract from inline code" do
      result = extract("use `@channel` carefully, @alice")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(result).to include("`@channel`")
    end
  end

  # The contract: every token spliced into the result maps to exactly one recorded
  # linkage descriptor.
  it "keeps placeholders and linkage rows one-to-one" do
    result =
      extract(
        "intro @carol see ![pic](upload://h45h.png) and " \
          "[quote=\"dan, post:9, topic:3\"]q[/quote] done",
      )

    expect(Migrations::Placeholder.scan(result)).to match_array(buffer.placeholders)
  end

  describe "Unicode raw" do
    it "leaves a body of only Unicode text untouched" do
      raw = "これは 🎉 café テスト — nothing to extract"

      expect(extract(raw)).to eq(raw)
      expect(buffer).to be_empty
    end

    it "captures a whole Unicode username, not just its ASCII prefix" do
      extract("cc @café_team here")

      expect(buffer.mentions.first[:name]).to eq("café_team")
    end

    it "captures a username with a combining mark (decomposed form)" do
      name = "José".unicode_normalize(:nfd)
      extract("ping @#{name} thanks")

      captured = buffer.mentions.first[:name]
      expect(captured.unicode_normalize).to eq("José".unicode_normalize)
    end

    it "captures a CJK username" do
      extract("hi @田中 there")

      expect(buffer.mentions.first[:name]).to eq("田中")
    end

    it "does not treat @name after a Unicode letter as a mention" do
      raw = "café@john"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "preserves Unicode around an extracted embed and stays valid encoding" do
      result = extract("日本語 ![絵](upload://abc.png) 🎉")

      expect(buffer.uploads.size).to eq(1)
      expect(result).to eq("日本語 #{buffer.uploads.first[:placeholder]} 🎉")
      expect(result).to be_valid_encoding
    end

    it "does not extract embeds from a code block that contains Unicode" do
      raw = "```\n@josé [quote=\"x, post:1\"] 日本\n```\n@real"
      result = extract(raw)

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[real])
      expect(result).to include("@josé", '[quote="x, post:1"]', "日本")
    end

    # Multibyte text BEFORE a construct shifts every later byte offset away from
    # its character offset, so any byte-indexed look-back reads the wrong byte.
    # These bodies are shaped so that wrong byte is an alphanumeric — a boundary
    # check that mixes up the two index kinds rejects the construct.
    context "with multibyte text before the construct" do
      it "still defers a mention" do
        result = extract("héllo @alice hi")

        expect(buffer.mentions.first[:name]).to eq("alice")
        expect(result).to eq("héllo #{buffer.mentions.first[:placeholder]} hi")
      end

      it "still defers a hashtag" do
        extract("höhe #support da")

        expect(buffer.hashtags.first[:name]).to eq("support")
      end

      it "still defers a bare internal link" do
        extract("Höhe /t/thema/9 an")

        expect(buffer.links.first).to include(target_id: 9)
      end

      it "still defers a custom emoji" do
        emoji_extractor = described_class.new(custom_emoji_names: %w[parrot])
        emoji_extractor.extract("schön :parrot:", embeds: buffer)

        expect(buffer.emojis.first[:name]).to eq("parrot")
      end

      it "still keeps a glued mention literal" do
        raw = "das naïve@alice bleibt"

        expect(extract(raw)).to eq(raw)
        expect(buffer.mentions).to be_empty
      end
    end
  end
end
