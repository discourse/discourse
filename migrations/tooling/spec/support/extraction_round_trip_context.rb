# frozen_string_literal: true

require "tmpdir"

# Scaffolding for the extraction round-trip spec: the fixture bodies, the source
# site the extractor is configured for, a maps object where nothing resolves,
# and the runner that drives extraction and resolution against each other.
module ExtractionRoundTrip
  FIXTURES_PATH = File.expand_path("../fixtures/extraction_round_trip", __dir__)

  # The source site: one host on a subdirectory install plus the domain it used
  # before, so absolute links on either spelling, prefixed relative links and
  # foreign hosts all occur in the fixtures.
  SOURCE_HOST = "forum.example.com"
  SOURCE_PREFIX = "/community"
  FORMER_HOST = "old.example.com"
  HOSTS = { SOURCE_HOST => SOURCE_PREFIX, FORMER_HOST => nil }.freeze

  # The destination's base URL. Unreachable on purpose: a link only carries it
  # when resolution put it there.
  BASE_URL = "https://unresolved.invalid"

  # Every fixture body is a post in this topic, so a quote naming only a
  # `post:` has a topic to be completed from.
  TOPIC_ID = 42

  MENTION_NAMES = %w[alice all bob here staff].freeze
  GROUP_NAMES = %w[staff].freeze
  HASHTAG_NAMES = %w[howto support support:billing].freeze
  CUSTOM_EMOJI_NAMES = %w[partyparrot].freeze

  # The fixture that is expected to defeat the extractor; it is asserted on
  # separately, not round-tripped.
  REFUSED_FIXTURE = "refused_route"

  # CR line endings take a different path through the scanner, so one body is
  # rewritten here rather than stored — a checkout normalizes line endings.
  CRLF_SOURCE = "mixed"
  CRLF_FIXTURE = "mixed_crlf"

  # What one run of the fixture set produced; each value is keyed by fixture
  # name, except the tallies.
  Outcome =
    Data.define(
      :extracted,
      :expected,
      :resolved,
      :placeholders,
      :refusals,
      :orphans,
      :engine_bound,
      :live_scans,
    )

  def self.fixtures
    @fixtures ||=
      Dir[File.join(FIXTURES_PATH, "*.md")]
        .sort
        .to_h { |path| [File.basename(path, ".md"), File.read(path, encoding: Encoding::UTF_8)] }
        .freeze
  end

  # The bodies the round-trip properties hold for, in a stable order.
  def self.round_trip_bodies
    @round_trip_bodies ||=
      fixtures
        .except(REFUSED_FIXTURE)
        .merge(CRLF_FIXTURE => fixtures.fetch(CRLF_SOURCE).gsub("\n", "\r\n"))
        .freeze
  end

  # Building an engine context means a V8 isolate evaluating the whole engine
  # bundle, so the file shares one; contexts are stateless across scans.
  def self.markdown_engine
    @markdown_engine ||=
      Migrations::Converters::MarkdownEngine::Context.new(
        bundle: Migrations::Converters::MarkdownEngine::Bundle.load_or_build,
        config:
          Migrations::Converters::MarkdownEngine::Config.new(
            source_settings: {
              "unicode_usernames" => true,
            },
            category_slugs: HASHTAG_NAMES,
            tag_names: HASHTAG_NAMES,
            custom_emoji_names: CUSTOM_EMOJI_NAMES,
          ),
      )
  end

  def self.close_markdown_engine
    @markdown_engine&.close
    @markdown_engine = nil
  end

  # Every lookup misses, so resolution has nothing but each row's recorded
  # source to fall back on. A link to the source site is the exception the
  # contract allows: its origin always becomes the destination's.
  class AllMissMaps
    %i[
      badge
      category_id
      category_slug_path
      emoji_name
      event_markdown
      group_name
      poll_markdown
      post
      tag_id
      tag_name
      topic_id
      upload
      upload_markdown
      user
    ].each { |name| define_method(name) { |_key| nil } }

    def base_url
      BASE_URL
    end

    def here_mention
      "here"
    end
  end
end

RSpec.configure { |config| config.after(:suite) { ExtractionRoundTrip.close_markdown_engine } }

RSpec.shared_context "with extraction round trip" do
  let(:enums) { Migrations::Database::IntermediateDB::Enums }
  let(:owner_type) { enums::EmbedOwner::POST }

  # Small enough that the fixture set spans several engine calls.
  let(:batch_size) { 4 }

  # Extracts each body into a real buffer, writes the embed rows the way a
  # converter step does, and resolves the whole set back in one call.
  #
  # @param batched [Boolean] whether the engine-bound bodies go through
  #   `scan_batches` or are scanned one at a time inside `extract_prepared`.
  def round_trip(bodies, batched: true)
    with_intermediate_db { |db| extract_and_resolve(bodies, db, batched:) }
  end

  def extract_and_resolve(bodies, intermediate_db, batched:)
    refusals = Hash.new(0)
    # A fixed nonce makes the tokens of two runs comparable.
    buffer =
      Migrations::Converters::EmbedBuffer.new(
        owner_type:,
        placeholder: Migrations::Placeholder.new(nonce: "roundtrip"),
      )
    extractor = build_extractor(buffer, refusals)

    names = bodies.keys
    prepared =
      bodies.map.with_index do |(_name, raw), index|
        extractor.prepare(raw:, id: index + 1, topic_id: ExtractionRoundTrip::TOPIC_ID)
      end
    scan_data = batched ? extractor.scan_batches(prepared, max_posts: batch_size) : {}

    extracted = {}
    expected = {}
    placeholders = {}
    engine_bound = 0
    live_scans = 0
    items = []

    prepared.each_with_index do |body, index|
      name = names[index]
      data = scan_data[body.id]
      if body.engine_bound?
        engine_bound += 1
        live_scans += 1 if data.nil?
      end

      buffer.clear
      output = extractor.extract_prepared(body, scan_data: data)
      buffer.write_for(body.id) unless buffer.empty?

      extracted[name] = output
      expected[name] = expected_all_miss_body(output, buffer)
      placeholders[name] = buffer.placeholders
      items << { id: body.id, raw: output }
    end

    orphans = []
    resolver =
      Migrations::Importer::PlaceholderResolver.new(
        intermediate_db,
        ExtractionRoundTrip::AllMissMaps.new,
        owner_type:,
        unresolved_embeds: [],
        orphan_placeholders: orphans,
      )
    resolved = resolver.resolve_all(items)

    ExtractionRoundTrip::Outcome.new(
      extracted:,
      expected:,
      resolved: names.each_with_index.to_h { |name, index| [name, resolved[index + 1]] },
      placeholders:,
      refusals:,
      orphans:,
      engine_bound:,
      live_scans:,
    )
  end

  def build_extractor(buffer, refusals)
    Migrations::Converters::Discourse::RawExtractor.new(
      embeds: buffer,
      mention_names: compact_set(ExtractionRoundTrip::MENTION_NAMES),
      hashtag_names: compact_set(ExtractionRoundTrip::HASHTAG_NAMES),
      custom_emoji_names: ExtractionRoundTrip::CUSTOM_EMOJI_NAMES,
      markdown_engine: ExtractionRoundTrip.markdown_engine,
      internal_link_hosts: ExtractionRoundTrip::HOSTS,
      internal_link_base_prefix: ExtractionRoundTrip::SOURCE_PREFIX,
      mention_classifier:
        Migrations::Converters::Discourse::MentionClassifier.new(
          here_mention: "here",
          group_names: ExtractionRoundTrip::GROUP_NAMES,
        ),
      on_engine_refusal: ->(cause, _detail) { refusals[cause] += 1 },
    )
  end

  def compact_set(names)
    Migrations::CompactStringSet.new(
      names.map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end

  def with_intermediate_db
    Dir.mktmpdir("extraction-round-trip") do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      database = Migrations::Database.connect(db_path)
      # The intermediate `posts` table arrives with the posts import step. The
      # resolver reads it to turn a quote's `topic:`/`post:` pair into a source
      # post id, so the round trip carries the minimal forward shim.
      database.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS posts (
          original_id NUMERIC NOT NULL PRIMARY KEY,
          topic_id NUMERIC,
          post_number INTEGER
        )
      SQL
      Migrations::Database::IntermediateDB.setup(database)
      yield database
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
      database&.close
    end
  end

  # The byte-exact expectation for one body: the extracted raw with every token
  # put back the way an all-miss resolution has to put it back.
  def expected_all_miss_body(output, buffer)
    embed_rows(buffer).reduce(output) do |expected, (kind, row)|
      replacement = expected_replacement(kind, row)
      # The block form keeps a `\` in a snippet from being read as a
      # backreference.
      replacement ? expected.sub(row[:placeholder]) { replacement } : expected
    end
  end

  def expected_replacement(kind, row)
    if kind == :link && row[:target_type] == enums::LinkTarget::SITE
      expected_site_markup(row)
    elsif kind == :emoji
      # An emoji row carries no snippet: its name is the source spelling.
      ":#{row[:name]}:"
    else
      row[:original_markdown]
    end
  end

  # A link to the source site has no entity to miss — only its origin moves —
  # so the expectation splices the rewritten destination itself. The arithmetic
  # is independent of the resolver's: the path comes from the row's own URL
  # spelling rather than from `target_suffix`, so a wrongly recorded suffix
  # still fails. A row without a usable span returns nil, which leaves the token
  # in the expectation and fails the comparison loudly.
  def expected_site_markup(row)
    original = row[:original_markdown]
    offset = row[:url_offset]
    return nil if original.nil? || offset.nil?

    length = row[:url].bytesize
    return nil if offset < 0 || offset + length > original.bytesize

    spans = [offset]
    label = row[:label_url_offset]
    spans << label if label && label != offset && label >= 0 && label + length <= original.bytesize

    url = expected_site_url(row)
    expected = original.dup
    spans.sort.reverse_each { |span| expected.bytesplice(span, length, url) }
    expected
  end

  def expected_site_url(row)
    origin = Migrations::Converters::Discourse::MarkdownScanner::UrlOrigin
    host, rest = origin.split(row[:url])
    hosts = ExtractionRoundTrip::HOSTS
    path =
      if host && hosts.key?(host)
        origin.path_within_prefix(rest, hosts[host])
      else
        row[:target_suffix]
      end

    "#{ExtractionRoundTrip::BASE_URL}#{path}"
  end

  def embed_rows(buffer)
    {
      quote: buffer.quotes,
      link: buffer.links,
      mention: buffer.mentions,
      hashtag: buffer.hashtags,
      emoji: buffer.emojis,
      poll: buffer.polls,
      event: buffer.events,
      upload: buffer.uploads,
    }.flat_map { |kind, rows| rows.map { |row| [kind, row] } }
  end
end
