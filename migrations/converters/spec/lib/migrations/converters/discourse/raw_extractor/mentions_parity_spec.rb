# frozen_string_literal: true

# Cross-checks the mention detector against what core actually renders. For every
# boundary character in a representative set we build `a<char>@someuser x` (and the
# forward variant `a @someuser<char> x`) and assert the detector extracts exactly
# when `PrettyText.cook` produces a cooked mention link. Mentions run through the
# same text-post-process engine as hashtags, which imposes a whitespace-or-
# punctuation boundary on both sides of the whole match that the rule regex never
# shows, so the boundary is checked here against PrettyText rather than read off
# core's regex. Needs a booted Rails environment, so it is tagged `:rails` and runs
# only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  # The detector reads a username the Unicode-aware way (`@café`), which can only
  # be a real source username when the source ran with unicode usernames on, so
  # that is the setting under which the two sides are comparable. With it off core
  # would use an ASCII-only `\w` name and no multibyte username could exist to gate
  # on anyway.
  before do
    SiteSetting.enable_mentions = true
    SiteSetting.unicode_usernames = true
  end

  let!(:user) { Fabricate(:user, username: "someuser") }

  # Extraction is gated on the source's names, so the detector defers only a
  # mention that names something real — the same condition under which core cooks a
  # link (a name that resolves to nothing cooks an inert `<span class="mention">`).
  let(:mention_names) do
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("someuser")])
  end

  # This spec is not about hashtags; the extractor requires the set anyway.
  let(:hashtag_names) { Migrations::CompactStringSet.new([]) }
  let(:markdown_engine) { MarkdownEngineHelper.context_for_names(hashtag_names: []) }

  # The 32 ASCII punctuation characters (CommonMark), which already include the
  # ASCII symbols `$ + < = > ^ \` | ~`, plus letters, whitespace, and Unicode
  # punctuation/symbol characters that exercise the boundary from both sides. The
  # last three are the telling ones: `²` and `½` are category No and `­` (soft
  # hyphen) is category Cf — none are a word character, a space, or punctuation, so
  # they separate a plain word boundary from core's punctuation-or-space boundary.
  def boundary_chars
    ascii_punctuation =
      [0x21..0x2f, 0x3a..0x40, 0x5b..0x60, 0x7b..0x7e].flat_map(&:to_a)
        .to_h { |cp| [format("U+%04X", cp), cp.chr(Encoding::UTF_8)] }

    {
      "letter a" => "a",
      "digit 9" => "9",
      "e-acute" => "é",
      "han" => "漢",
      "space" => " ",
      "tab" => "\t",
      "newline" => "\n",
      "no-break space" => " ",
      "ideographic space" => "　",
      "em dash" => "—",
      "low double quote" => "„",
      "left guillemet" => "«",
      "ellipsis" => "…",
      "euro sign" => "€",
      "superscript two" => "²",
      "vulgar half" => "½",
      "soft hyphen" => "­",
    }.merge(ascii_punctuation)
  end

  def detector_extracts?(raw)
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:).extract(
      raw,
    )
    buffer.mentions.any?
  end

  # A real rendered mention is an anchor link. Core cooks an inert
  # `<span class="mention">` (no link) for a name that resolves to nothing, so the
  # anchor is what tells apart a mention core actually rendered.
  def core_cooks?(raw)
    PrettyText.cook(raw, user_id: user.id).include?('<a class="mention"')
  end

  def describe_char(char)
    codepoints = char.each_codepoint.map { |cp| format("U+%04X", cp) }.join(" ")
    "#{char.inspect} (#{codepoints})"
  end

  def deviations_for(direction)
    boundary_chars.filter_map do |label, char|
      raw = direction == :before ? "a#{char}@someuser x" : "a @someuser#{char} x"
      extracted = detector_extracts?(raw)
      cooked = core_cooks?(raw)
      next if extracted == cooked

      "#{direction} #{label} #{describe_char(char)}: detector=#{extracted} core=#{cooked}"
    end
  end

  it "extracts exactly when core cooks, for every character before the `@`" do
    deviations = deviations_for(:before)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "extracts exactly when core cooks, for every character after the name" do
    deviations = deviations_for(:forward)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "extracts a mention at the very start of the input, matching core" do
    raw = "@someuser x"
    expect(detector_extracts?(raw)).to eq(core_cooks?(raw))
  end

  describe "name shapes" do
    def extracted_name(raw, name)
      buffer =
        Migrations::Converters::EmbedBuffer.new(
          owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
        )
      names = Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize(name)])
      described_class.new(
        embeds: buffer,
        mention_names: names,
        hashtag_names:,
        markdown_engine:,
      ).extract(raw)
      buffer.mentions.first&.[](:name)
    end

    # The name core linked, read back from the `/u/<slug>` href (URL-encoded), so
    # `@café` links `caf%C3%A9`.
    def cooked_link(raw)
      slug = PrettyText.cook(raw, user_id: user.id)[%r{href="/u/([^"]+)"}, 1]
      slug && CGI.unescape(slug)
    end

    [
      ["john.doe", "hi @john.doe there", "john.doe"], # interior dot
      ["john", "thanks @john.", "john"], # trailing dot dropped
      ["j-d", "cc @j-d please", "j-d"], # interior dash
      ["user", "ping @user_ here", "user"], # trailing underscore dropped
      ["café", "cc @café here", "café"], # multibyte
    ].each do |username, raw, expected|
      it "reads #{raw.inspect} the same name core links" do
        Fabricate(:user, username:)
        expect(extracted_name(raw, username)).to eq(expected)
        expect(cooked_link(raw)).to eq(expected)
      end
    end
  end

  # The one deliberate divergence: core's name regex caps a username at 60
  # characters, so a longer `@name` cooks nothing, while the detector has no cap and
  # extracts it. A name that long can't be a real source username (Discourse's own
  # limit is 60), so the gate never defers one — the cap is moot, and we keep the
  # simpler capless detector.
  it "leaves an over-long name literal, matching core's 60-character cap" do
    # The detector grammar itself has no length cap, but the engine's mention
    # rule does — and no token means nothing certifies, so extraction inherits
    # core's cap without duplicating it.
    long = "u#{"a" * 60}" # 61 characters
    names = Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize(long)])
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
      )
    described_class.new(
      embeds: buffer,
      mention_names: names,
      hashtag_names:,
      markdown_engine:,
    ).extract("hi @#{long} x")

    expect(buffer.mentions).to be_empty
    expect(core_cooks?("hi @#{long} x")).to be(false)
  end
end
