# frozen_string_literal: true

# Cross-checks the full-URL upload construct's bare-URL boundary against what core
# renders. It shares {Base#bare_url_boundary_before?} with the internal-link
# construct, so it rides the same linkify boundary (see
# `internal_links_parity_spec.rb`); this smaller battery confirms an upload URL —
# recognized by its 40-hex sha1, not by a route — admits at the same characters.
# For every boundary character we build `a<char><upload-url> b` (and the forward
# variant) and assert the construct defers exactly when `PrettyText.cook` linkifies
# an anchor for the URL. Needs a booted Rails environment, so it is tagged `:rails`
# and runs only under `MIGRATIONS_RAILS=1`.
RSpec.describe Migrations::Converters::Discourse::RawExtractor, :rails do
  include_context "with parity extractor"

  before { SiteSetting.enable_markdown_linkify = true }

  def url
    sha1 = "0123456789abcdef0123456789abcdef01234567"
    "https://cdn.example.com/uploads/default/original/2X/a/ab/#{sha1}.png"
  end

  def construct_extracts?(raw)
    buffer = new_buffer
    build_extractor(buffer).extract(raw)
    buffer.uploads.any?
  end

  def core_links?(raw)
    hrefs = PrettyText.cook(raw).scan(/<a\b[^>]*href="([^"]*)"/).flatten
    hrefs.any? { |href| href.start_with?(url) }
  end

  def deviations_for(direction)
    BoundaryCorpus.chars.filter_map do |label, char|
      raw = direction == :before ? "a#{char}#{url} b" : "a #{url}#{char} b"
      extracted = construct_extracts?(raw)
      linkified = core_links?(raw)
      next if extracted == linkified

      "#{direction} #{label} #{BoundaryCorpus.describe(char)}: " \
        "construct=#{extracted} core=#{linkified}"
    end
  end

  it "defers exactly when core linkifies, for every character before the URL" do
    deviations = deviations_for(:before)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  # The sha1 sits mid-URL, so a trailing character never disturbs recognition and
  # the `\w` tail trims the same trailing punctuation linkify does — both sides
  # keep the URL and drop what follows, so the whole set is parity.
  it "defers exactly when core linkifies, for every character after the URL" do
    deviations = deviations_for(:forward)
    expect(deviations).to be_empty, -> { deviations.join("\n") }
  end

  it "defers at the very start of the input, matching core" do
    raw = "#{url} b"
    expect(construct_extracts?(raw)).to eq(core_links?(raw))
  end

  # The converter decodes `/uploads/short-url/<token>` without core on the
  # load path, so it carries its own base62 decoder. This pins it to core's;
  # a drift here means short-URL rows stop matching their upload rows.
  it "decodes short-URL tokens the way core does" do
    tokens = %w[21 aZ9 Zm9vYmFy 2Yjf3WE4KOQ88YUb4fUMubKB9My zzzzzzzzzzzzzzzzzzzzzzzzzzz 0]
    tokens.each do |token|
      expect(
        Migrations::Converters::Discourse::MarkdownScanner::Constructs::UploadUrl.sha1_from_short_token(
          token,
        ),
      ).to eq(Upload.sha1_from_base62_encoded(token)),
      "token #{token.inspect} decoded differently"
    end
  end
end
