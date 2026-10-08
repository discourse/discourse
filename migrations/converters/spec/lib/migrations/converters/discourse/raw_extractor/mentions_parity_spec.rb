# frozen_string_literal: true

# Cross-checks the mention construct against what core actually renders. For every
# boundary character in a representative set we build `a<char>@someuser x` (and the
# forward variant `a @someuser<char> x`) and assert the construct extracts exactly
# when `PrettyText.cook` produces a cooked mention link. Mentions run through the
# same text-post-process engine as hashtags, which imposes a whitespace-or-
# punctuation boundary on both sides of the whole match that the rule regex never
# shows, so the boundary is checked here against PrettyText rather than read off
# core's regex. Needs a booted Rails environment, so it is tagged `:rails` and runs
# only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  include_context "with parity extractor"

  # The construct reads a username the Unicode-aware way (`@café`), which can only
  # be a real source username when the source ran with unicode usernames on, so
  # that is the setting under which the two sides are comparable. With it off core
  # would use an ASCII-only `\w` name and no multibyte username could exist to gate
  # on anyway.
  before do
    SiteSetting.enable_mentions = true
    SiteSetting.unicode_usernames = true
  end

  let!(:user) { Fabricate(:user, username: "someuser") }

  # Extraction is gated on the source's names, so the construct defers only a
  # mention that names something real — the same condition under which core cooks a
  # link (a name that resolves to nothing cooks an inert `<span class="mention">`).
  let(:mention_names) do
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("someuser")])
  end

  def construct_extracts?(raw)
    buffer = new_buffer
    build_extractor(buffer).extract(raw)
    buffer.mentions.any?
  end

  # A real rendered mention is an anchor link. Core cooks an inert
  # `<span class="mention">` (no link) for a name that resolves to nothing, so the
  # anchor is what tells apart a mention core actually rendered.
  def core_cooks?(raw)
    PrettyText.cook(raw, user_id: user.id).include?('<a class="mention"')
  end

  def deviations_for(direction)
    BoundaryCorpus.chars.filter_map do |label, char|
      raw = direction == :before ? "a#{char}@someuser x" : "a @someuser#{char} x"
      extracted = construct_extracts?(raw)
      cooked = core_cooks?(raw)
      next if extracted == cooked

      "#{direction} #{label} #{BoundaryCorpus.describe(char)}: construct=#{extracted} core=#{cooked}"
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
    expect(construct_extracts?(raw)).to eq(core_cooks?(raw))
  end

  describe "name shapes" do
    def extracted_name(raw, name)
      buffer = new_buffer
      names = Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize(name)])
      build_extractor(buffer, mention_names: names).extract(raw)
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
  # characters, so a longer `@name` cooks nothing, while the construct has no cap and
  # extracts it. A name that long can't be a real source username (Discourse's own
  # limit is 60), so the gate never defers one — the cap is moot, and we keep the
  # simpler capless construct.
  it "leaves an over-long name literal, matching core's 60-character cap" do
    # The construct grammar itself has no length cap, but the engine's mention
    # rule does — and no token means nothing matches, so extraction inherits
    # core's cap without duplicating it.
    long = "u#{"a" * 60}" # 61 characters
    names = Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize(long)])
    buffer = new_buffer
    build_extractor(buffer, mention_names: names).extract("hi @#{long} x")

    expect(buffer.mentions).to be_empty
    expect(core_cooks?("hi @#{long} x")).to be(false)
  end
end
