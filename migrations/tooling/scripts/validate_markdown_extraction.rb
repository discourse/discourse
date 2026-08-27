# frozen_string_literal: true

# Runs the markdown extraction machinery the way the future posts step will run
# it — real fork model, real engine contexts, real embed writes — against a
# Discourse corpus, and proves two things at scale:
#
#   correctness  every extracted body is resolved back in "all-miss" mode (no
#                reference resolves) and must match the computed expectation
#                byte for byte: the input, except that each SITE link — an
#                origin-only rewrite with no entity to miss — is rewritten to
#                precisely the base URL plus the path derived from the row's
#                own URL spelling. Everything else is the verbatim-fallback
#                contract, checked against every post in the corpus. Any diff
#                beyond the expectation is a bug and fails the run.
#   viability    end-to-end throughput, per-worker RSS, refusal/trial tallies,
#                and per-post vs batched engine calls — the numbers a posts
#                step must reproduce.
#
# Process model mirrors a converter run: the parent builds the engine bundle
# (subprocess build on a cold cache; the parent itself never initializes V8),
# loads the source name sets into compact copy-on-write sets, forks workers via
# ForkManager, and each worker builds its own engine context and RawExtractor
# after the fork, reads an id-range partition of `posts`, extracts through a
# real EmbedBuffer into a throwaway intermediate database, and round-trips the
# result through the real PlaceholderResolver.
#
# Usage (from the repo root, under the root bundle with the migrations group —
# the resolver lives in the importer gem, which the converters bundle doesn't
# carry):
#
#   BUNDLE_WITH=migrations bundle exec ruby \
#     migrations/tooling/scripts/validate_markdown_extraction.rb \
#     --dbname discourse --forum-host forum.example.com --workers 8
#
# `--round-trip identity-hit` additionally loads the corpus's users, groups,
# posts, categories and tags into the throwaway database and resolves every
# reference to itself. Hits legitimately rewrite spellings (a quote header is
# canonicalized, a link destination is rebuilt from the resolved route, a
# hashtag takes the resolved slug's case), so in that mode byte diffs on posts
# carrying such embeds are reported as expected rewrites; a diff on a post with
# only mention/emoji/upload embeds still fails. `--batch N` scans N
# engine-bound bodies per V8 call instead of one, through the same production
# `extract(..., scan_data:)` seam a batching posts step would use.
# `--log-refusals N` samples up to N refusing post ids per cause and worker
# (with the exception class behind an :engine_error), so a corpus run's refusal
# tally is diagnosable without a rerun.

require "optparse"

options = {
  dbname: nil,
  db_host: nil,
  db_port: nil,
  db_user: nil,
  forum_hosts: [],
  workers: 4,
  limit: nil,
  read_batch: 500,
  batch: nil,
  round_trip: "all-miss",
  cold_bundle: false,
  log_refusals: 0,
}

OptionParser
  .new do |parser|
    parser.on("--dbname NAME", "Corpus database name (required)") { |v| options[:dbname] = v }
    parser.on("--db-host HOST", "Database host (default: unix socket)") do |v|
      options[:db_host] = v
    end
    parser.on("--db-port PORT", Integer, "Database port") { |v| options[:db_port] = v }
    parser.on("--db-user USER", "Database user") { |v| options[:db_user] = v }
    parser.on("--forum-host HOST", "Source forum host, repeatable") do |v|
      options[:forum_hosts] << v
    end
    parser.on("--workers N", Integer, "Worker processes (default 4)") { |v| options[:workers] = v }
    parser.on("--limit N", Integer, "Only the first N posts by id") { |v| options[:limit] = v }
    parser.on("--read-batch N", Integer, "Rows per corpus query (default 500)") do |v|
      options[:read_batch] = v
    end
    parser.on("--batch N", Integer, "Engine-bound bodies per V8 scan call (default: one)") do |v|
      options[:batch] = v
    end
    parser.on(
      "--round-trip MODE",
      %w[all-miss identity-hit],
      "all-miss (default) or identity-hit",
    ) { |v| options[:round_trip] = v }
    parser.on("--cold-bundle", "Delete the bundle cache first to time a cold build") do
      options[:cold_bundle] = true
    end
    parser.on(
      "--log-refusals N",
      Integer,
      "Sample up to N refusing post ids per cause, per worker",
    ) { |v| options[:log_refusals] = v }
  end
  .parse!

abort("--dbname is required") if options[:dbname].nil?

require "delegate"
require "fileutils"
require "json"
require "tmpdir"
require "migrations-converters"
require "migrations-importer"
require "pg"

MarkdownEngine = Migrations::Converters::MarkdownEngine
EmbedOwner = Migrations::Database::IntermediateDB::Enums::EmbedOwner
LinkTarget = Migrations::Database::IntermediateDB::Enums::LinkTarget
UrlOrigin = Migrations::Converters::Discourse::MarkdownScanner::UrlOrigin

def monotonic_time
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

def rss_mib
  File.read("/proc/self/status")[/^VmRSS:\s+(\d+) kB/, 1].to_f / 1024
end

# Proportional set size splits shared pages across their sharers, so it is the
# honest number for the copy-on-write question; not every kernel exposes it.
def pss_mib
  File.read("/proc/self/smaps_rollup")[/^Pss:\s+(\d+) kB/, 1].to_f / 1024
rescue Errno::ENOENT, Errno::EACCES
  nil
end

# The same normalization RawExtractor#extract applies; the round-trip compares
# against what the extractor actually worked on.
def normalize_body(raw)
  if raw.encoding == Encoding::UTF_8
    raw.valid_encoding? ? raw : raw.scrub
  else
    raw.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end
end

# A SITE link resolves deterministically in every mode — only its origin moves
# to the destination base — so the all-miss expectation must rewrite it too.
# The path is derived from the row's own URL spelling rather than the row's
# recorded suffix, so a wrongly recorded suffix still surfaces as a violation;
# only a schemeless bare-domain spelling (which the origin reading can't split)
# falls back to the recorded suffix.
def expected_site_url(row, hosts, base_url)
  host, rest = UrlOrigin.split(row[:url])
  path =
    if host && hosts.key?(host)
      UrlOrigin.path_within_prefix(rest, hosts[host])
    else
      row[:target_suffix]
    end
  "#{base_url}#{path}"
end

# The harness's own splice of the rewritten destination into the verbatim
# snippet — independent arithmetic over the same row fields the resolver uses,
# so a resolver splicing bug shows up as a byte diff. A row without a usable
# span returns nil, the caller then leaves the placeholder in the expectation,
# and the comparison fails loudly — which is the point.
def expected_site_markup(row, hosts, base_url)
  url = expected_site_url(row, hosts, base_url)
  original = row[:original_markdown]
  offset = row[:url_offset]
  return nil if original.nil? || offset.nil?

  length = row[:url].bytesize
  return nil if offset < 0 || offset + length > original.bytesize

  spans = [offset]
  label = row[:label_url_offset]
  spans << label if label && label != offset && label >= 0 && label + length <= original.bytesize
  expected = original.dup
  spans.sort.reverse_each { |span| expected.bytesplice(span, length, url) }
  expected
end

def each_embed_row(buffer)
  {
    quote: buffer.quotes,
    link: buffer.links,
    mention: buffer.mentions,
    hashtag: buffer.hashtags,
    emoji: buffer.emojis,
    poll: buffer.polls,
    event: buffer.events,
    upload: buffer.uploads,
  }.each { |kind, rows| rows.each { |row| yield kind, row } }
end

# The exact byte expectation for a post in all-miss mode: every placeholder
# substituted back with its verbatim source — except a SITE link, whose
# deterministic origin rewrite is computed here. Placeholder tokens are
# delimiter-wrapped and unique, so plain literal substitution is unambiguous;
# the block form keeps `\`-sequences in a snippet from being read as
# backreferences.
def expected_all_miss_body(output, buffer, hosts, base_url, stats)
  expected = output
  each_embed_row(buffer) do |kind, row|
    replacement =
      if kind == :link && row[:target_type] == LinkTarget::SITE
        stats["site_rewrites"] += 1
        expected_site_markup(row, hosts, base_url)
      else
        row[:original_markdown]
      end
    expected = expected.sub(row[:placeholder]) { replacement } if replacement
  end
  expected
end

def connect_corpus(options)
  connection =
    PG::Connection.new(
      {
        dbname: options[:dbname],
        host: options[:db_host],
        port: options[:db_port],
        user: options[:db_user],
      }.compact,
    )
  connection.type_map_for_results = PG::BasicTypeMapForResults.new(connection)
  connection
end

# Counts the engine calls the extraction makes and the wall time spent inside
# V8, without touching production code: RawExtractor sees this wrapper as its
# engine context.
class CountingContext < SimpleDelegator
  attr_reader :calls, :seconds

  def initialize(context)
    super
    @calls = 0
    @seconds = 0.0
  end

  def scan(posts)
    @calls += 1
    started_at = monotonic_time
    __getobj__.scan(posts)
  ensure
    @seconds += monotonic_time - started_at
  end

  private

  def monotonic_time
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end

# The resolver reports every unresolved embed; at corpus scale that must not
# accumulate one record per upload, so this keeps counts plus a few samples.
class TallyCollector
  attr_reader :counts, :samples

  def initialize
    @counts = Hash.new(0)
    @samples = []
  end

  def <<(record)
    @counts[record.respond_to?(:kind) ? record.kind : :unknown] += 1
    @samples << record if @samples.size < 5
    self
  end

  def total
    @counts.values.sum
  end
end

# Every lookup misses: resolution must restore each embed's verbatim source,
# so the round-trip output has to equal the input byte for byte.
class AllMissMaps
  %i[
    user
    group_name
    post
    topic_id
    upload_markdown
    poll_markdown
    event_markdown
    category_slug_path
    category_id
    tag_name
    badge
    emoji_name
  ].each { |name| define_method(name) { |_key| nil } }

  def base_url
    "https://unresolved.invalid"
  end

  def here_mention
    "here"
  end
end

# Every reference resolves to its own source value, exercising the hit paths
# at scale. Uploads stay unresolved on purpose: their identity rendering is
# the verbatim source, which the miss path already restores.
class IdentityMaps
  def initialize(data, base_url)
    @data = data
    @base_url = base_url
  end

  def user(id)
    @data[:users][id]
  end

  def group_name(id)
    @data[:groups][id]
  end

  def post(id)
    @data[:posts][id]
  end

  def topic_id(id)
    @data[:topics].include?(id) ? id : nil
  end

  def upload_markdown(_id)
    nil
  end

  def poll_markdown(_id)
    nil
  end

  def event_markdown(_id)
    nil
  end

  def category_slug_path(id)
    @data[:categories][id]&.fetch(:slug_path)
  end

  def category_id(id)
    @data[:categories].key?(id) ? id : nil
  end

  def tag_name(id)
    @data[:tags][id]
  end

  def badge(_id)
    nil
  end

  def emoji_name(name)
    name
  end

  attr_reader :base_url

  def here_mention
    "here"
  end
end

# --- parent: bundle, name sets, identity data, partitions ---

if options[:cold_bundle]
  cache_dir = File.join(MarkdownEngine.discourse_root, "tmp/migrations")
  Dir[File.join(cache_dir, "markdown-engine-bundle-*.json")].each { |file| File.delete(file) }
end

bundle_started_at = monotonic_time
bundle = MarkdownEngine::Bundle.load_or_build
bundle_seconds = monotonic_time - bundle_started_at
if defined?(AssetProcessor) && AssetProcessor.booted?
  abort("BUG: the parent process booted an AssetProcessor V8 context before forking")
end

corpus = connect_corpus(options)

mention_name_list =
  corpus.exec("SELECT username FROM users").column_values(0) +
    corpus.exec("SELECT name FROM groups").column_values(0) + %w[here all]
category_slugs = corpus.exec("SELECT slug FROM categories").column_values(0)
tag_names = corpus.exec("SELECT name FROM tags").column_values(0)
custom_emoji_names = corpus.exec("SELECT name FROM custom_emojis").column_values(0)
source_settings = corpus.exec("SELECT name, value FROM site_settings").values.to_h

identity_data = nil
if options[:round_trip] == "identity-hit"
  users = {}
  corpus
    .exec("SELECT id, username, name FROM users")
    .each { |row| users[row["id"]] = { username: row["username"], name: row["name"] } }
  groups = corpus.exec("SELECT id, name FROM groups").values.to_h
  posts = {}
  corpus
    .exec("SELECT id, topic_id, post_number FROM posts")
    .each do |row|
      posts[row["id"]] = { topic_id: row["topic_id"], post_number: row["post_number"] }
    end
  topics = corpus.exec("SELECT id FROM topics").column_values(0).to_set
  categories = {}
  slugs_by_id = {}
  parents = {}
  corpus
    .exec("SELECT id, slug, parent_category_id FROM categories")
    .each do |row|
      slugs_by_id[row["id"]] = row["slug"]
      parents[row["id"]] = row["parent_category_id"]
    end
  slugs_by_id.each_key do |id|
    parent = parents[id]
    path = parent ? "#{slugs_by_id[parent]}:#{slugs_by_id[id]}" : slugs_by_id[id]
    categories[id] = { slug: slugs_by_id[id], parent_id: parent, slug_path: path }
  end
  tags = corpus.exec("SELECT id, name FROM tags").values.to_h
  identity_data = { users:, groups:, posts:, topics:, categories:, tags: }
end

normalize = ->(names) { names.map { |name| Migrations::NameNormalizer.normalize(name) } }
mention_names = Migrations::CompactStringSet.new(normalize.call(mention_name_list))
hashtag_names = Migrations::CompactStringSet.new(normalize.call(category_slugs + tag_names))
internal_link_hosts = options[:forum_hosts].to_h { |host| [host.downcase, nil] }
base_url = "https://#{options[:forum_hosts].first || "source.invalid"}"

total = corpus.exec("SELECT count(*) FROM posts").getvalue(0, 0).to_i
total = [total, options[:limit]].min if options[:limit]
abort("corpus has no posts") if total == 0

worker_count = [options[:workers], total].min
per_worker = total / worker_count
boundaries =
  (1...worker_count).map do |k|
    corpus.exec("SELECT id FROM posts ORDER BY id OFFSET #{per_worker * k} LIMIT 1").getvalue(0, 0)
  end
partitions =
  worker_count.times.map do |k|
    lo = k == 0 ? 0 : boundaries[k - 1]
    hi = k == worker_count - 1 ? nil : boundaries[k]
    cap = k == worker_count - 1 ? total - per_worker * (worker_count - 1) : per_worker
    { lo:, hi:, cap: }
  end

# Workers open their own connections; the inherited descriptor must not be
# shared with children.
corpus.close

parent_rss_before_fork = rss_mib
run_started_at = monotonic_time

# --- workers ---

def run_worker(options, partition, bundle, config_inputs, identity_data, pipe)
  stats = {
    "posts" => 0,
    "bytes" => 0,
    "engine_posts" => 0,
    "engine_bytes" => 0,
    "embed_rows" => 0,
    "written_posts" => 0,
    "live_scans" => 0,
    "batch_scans" => 0,
    "violations" => 0,
    "expected_rewrites" => 0,
    "site_rewrites" => 0,
    "violation_samples" => [],
    "resolve_seconds" => 0.0,
  }
  rss_before = rss_mib

  corpus = connect_corpus(options)

  Dir.mktmpdir("markdown-validate") do |dir|
    db_path = File.join(dir, "intermediate.db")
    Migrations::Database.migrate(
      db_path,
      migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
    )
    intermediate = Migrations::Database.connect(db_path)
    # The posts step (and with it the intermediate `posts` table) is pending
    # work; the resolver's coordinate lookup needs the table, so the harness
    # carries the minimal forward shim.
    intermediate.execute(<<~SQL)
      CREATE TABLE IF NOT EXISTS posts (
        original_id NUMERIC NOT NULL PRIMARY KEY,
        topic_id NUMERIC,
        post_number INTEGER
      )
    SQL
    load_identity_rows(intermediate, identity_data) if identity_data
    Migrations::Database::IntermediateDB.setup(intermediate)

    context_started_at = monotonic_time
    engine =
      CountingContext.new(
        MarkdownEngine::Context.new(
          bundle:,
          config:
            MarkdownEngine::Config.new(
              source_settings: config_inputs[:source_settings],
              category_slugs: config_inputs[:category_slugs],
              tag_names: config_inputs[:tag_names],
              custom_emoji_names: config_inputs[:custom_emoji_names],
            ),
        ),
      )
    stats["context_init_seconds"] = monotonic_time - context_started_at
    stats["rss_after_context"] = rss_mib

    buffer = Migrations::Converters::EmbedBuffer.new(owner_type: EmbedOwner::POST)
    refusal_log = nil
    on_refusal = nil
    if options[:log_refusals] > 0
      refusal_log = { current_id: nil, samples: {} }
      on_refusal =
        lambda do |cause, detail|
          samples = (refusal_log[:samples][cause.to_s] ||= [])
          if samples.size < options[:log_refusals]
            id = refusal_log[:current_id]
            samples << (detail ? "#{id} (#{detail})" : id.to_s)
          end
        end
    end
    extractor =
      Migrations::Converters::Discourse::RawExtractor.new(
        embeds: buffer,
        mention_names: config_inputs[:mention_names],
        hashtag_names: config_inputs[:hashtag_names],
        custom_emoji_names: config_inputs[:custom_emoji_names].presence,
        internal_link_hosts: config_inputs[:internal_link_hosts],
        markdown_engine: engine,
        on_engine_refusal: on_refusal,
      )

    maps =
      if identity_data
        IdentityMaps.new(identity_data, config_inputs[:base_url])
      else
        AllMissMaps.new
      end
    unresolved = TallyCollector.new
    orphans = TallyCollector.new
    resolver =
      Migrations::Importer::PlaceholderResolver.new(
        intermediate,
        maps,
        owner_type: EmbedOwner::POST,
        unresolved_embeds: unresolved,
        orphan_placeholders: orphans,
      )

    started_at = monotonic_time
    each_partition_batch(corpus, partition, options[:read_batch]) do |rows|
      process_batch(
        rows,
        options,
        stats,
        extractor,
        engine,
        buffer,
        resolver,
        hosts: config_inputs[:internal_link_hosts],
        resolve_base: maps.base_url,
        refusal_log:,
      )
    end
    stats["extract_seconds"] = monotonic_time - started_at

    stats["refusals"] = extractor.engine_refusals
    stats["refusal_samples"] = refusal_log[:samples] if refusal_log
    stats["unresolved"] = unresolved.counts
    stats["orphans"] = orphans.total
    stats["scan_calls"] = engine.calls
    stats["scan_seconds"] = engine.seconds
    engine.close
    intermediate.close
  end

  corpus.close
  stats["rss_before_context"] = rss_before
  stats["rss_end"] = rss_mib
  stats["pss_end"] = pss_mib
  pipe.puts(JSON.generate(stats))
rescue => error
  pipe.puts(
    JSON.generate(
      { "error" => "#{error.class}: #{error.message}", "backtrace" => error.backtrace.first(8) },
    ),
  )
ensure
  pipe.close
end

def each_partition_batch(corpus, partition, read_batch)
  last_id = partition[:lo].to_i - 1
  remaining = partition[:cap]

  while remaining > 0
    upper = partition[:hi] ? "AND id < #{partition[:hi].to_i}" : ""
    rows =
      corpus.exec(
        "SELECT id, topic_id, raw FROM posts WHERE id > #{last_id} #{upper} " \
          "ORDER BY id LIMIT #{[read_batch, remaining].min}",
      )
    break if rows.ntuples == 0

    yield rows
    last_id = rows[rows.ntuples - 1]["id"]
    remaining -= rows.ntuples
  end
end

def process_batch(
  rows,
  options,
  stats,
  extractor,
  engine,
  buffer,
  resolver,
  hosts:,
  resolve_base:,
  refusal_log:
)
  scan_data_by_id = {}
  if options[:batch]
    engine_bound =
      rows.select do |row|
        raw = row["raw"]
        raw && !raw.empty? && raw.valid_encoding? && extractor.engine_bound?(raw)
      end
    engine_bound.each_slice(options[:batch]) do |slice|
      payload = slice.map { |row| { id: row["id"], raw: row["raw"] } }
      stats["batch_scans"] += 1
      engine.scan(payload).each { |data| scan_data_by_id[data["id"]] = data }
    end
  end

  items = []
  expected_bodies = {}
  rewrite_expected = {}
  all_miss = options[:round_trip] == "all-miss"

  rows.each do |row|
    raw = row["raw"]
    next if raw.nil? || raw.empty?

    normalized = normalize_body(raw)
    stats["posts"] += 1
    stats["bytes"] += normalized.bytesize

    engine_bound = extractor.engine_bound?(raw)
    scan_data = scan_data_by_id[row["id"]]
    if engine_bound
      stats["engine_posts"] += 1
      stats["engine_bytes"] += normalized.bytesize
      stats["live_scans"] += 1 if scan_data.nil?
    end

    buffer.clear
    refusal_log[:current_id] = row["id"] if refusal_log
    output = extractor.extract(raw, topic_id: row["topic_id"], scan_data:)

    unless buffer.empty?
      stats["embed_rows"] += buffer.placeholders.size
      stats["written_posts"] += 1
      buffer.write_for(row["id"])
      rewrite_expected[row["id"]] = buffer.quotes.any? || buffer.links.any? ||
        buffer.hashtags.any? || buffer.mentions.any?
    end

    items << { id: row["id"], raw: output }
    expected_bodies[row["id"]] = if all_miss && !buffer.empty?
      expected_all_miss_body(output, buffer, hosts, resolve_base, stats)
    else
      normalized
    end
  end

  resolve_started_at = monotonic_time
  resolved = resolver.resolve_all(items)
  stats["resolve_seconds"] += monotonic_time - resolve_started_at

  resolved.each do |id, body|
    next if body == expected_bodies[id]

    # Identity hits legitimately rewrite quote headers, link destinations,
    # hashtag slug case and mention username case; only a diff on a post
    # without any such embed can prove a bug in that mode.
    if !all_miss && rewrite_expected[id]
      stats["expected_rewrites"] += 1
      next
    end

    stats["violations"] += 1
    if stats["violation_samples"].size < 5
      stats["violation_samples"] << diff_sample(id, expected_bodies[id], body)
    end
  end
end

def diff_sample(id, expected, actual)
  index =
    (0...[expected.bytesize, actual.bytesize].min).find do |i|
      expected.getbyte(i) != actual.getbyte(i)
    end
  index ||= [expected.bytesize, actual.bytesize].min
  from = [index - 40, 0].max
  {
    "id" => id,
    "byte" => index,
    "expected" => expected.byteslice(from, 80).inspect,
    "actual" => actual.byteslice(from, 80).inspect,
  }
end

def load_identity_rows(intermediate, data)
  now = "2020-01-01 00:00:00"
  data[:users].each do |id, user|
    intermediate.insert(
      "INSERT INTO users (original_id, username, name, created_at, trust_level) " \
        "VALUES (?, ?, ?, ?, 1)",
      [id, user[:username], user[:name], now],
    )
  end
  data[:groups].each do |id, name|
    intermediate.insert("INSERT INTO \"groups\" (original_id, name) VALUES (?, ?)", [id, name])
  end
  data[:posts].each do |id, post|
    intermediate.insert(
      "INSERT INTO posts (original_id, topic_id, post_number) VALUES (?, ?, ?)",
      [id, post[:topic_id], post[:post_number]],
    )
  end
  data[:categories].each do |id, category|
    intermediate.insert(
      "INSERT INTO categories (original_id, name, slug, parent_category_id, user_id) " \
        "VALUES (?, ?, ?, ?, -1)",
      [id, category[:slug], category[:slug], category[:parent_id]],
    )
  end
  data[:tags].each do |id, name|
    intermediate.insert(
      "INSERT INTO tags (original_id, name, slug) VALUES (?, ?, ?)",
      [id, name, name],
    )
  end
  # No explicit commit: the resolver reads over the same connection, which
  # sees its own open transaction, and `close` finalizes it.
end

config_inputs = {
  source_settings:,
  category_slugs:,
  tag_names:,
  custom_emoji_names:,
  mention_names:,
  hashtag_names:,
  internal_link_hosts:,
  base_url:,
}

children =
  partitions.each_with_index.map do |partition, index|
    reader, writer = IO.pipe
    pid =
      Migrations::ForkManager.fork do
        reader.close
        run_worker(options, partition, bundle, config_inputs, identity_data, writer)
      end
    writer.close
    { index:, pid:, reader: }
  end

results =
  children.map do |child|
    payload = child[:reader].read
    child[:reader].close
    _pid, status = Process.wait2(child[:pid])
    result = payload.empty? ? { "error" => "worker wrote nothing" } : JSON.parse(payload.lines.last)
    result["exit_ok"] = status.success?
    result["worker"] = child[:index]
    result
  end

elapsed = monotonic_time - run_started_at

# --- report ---

def number(value)
  value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
end

failed = results.reject { |result| result["exit_ok"] && result["error"].nil? }
failed.each do |result|
  warn "worker #{result["worker"]} FAILED: #{result["error"]}"
  Array(result["backtrace"]).each { |line| warn "  #{line}" }
end

ok = results - failed
sum = ->(key) { ok.sum { |result| result[key] || 0 } }

puts format(
       "Bundle: %.1fs (%s), parent RSS before fork %.1f MiB",
       bundle_seconds,
       options[:cold_bundle] ? "cold, subprocess build" : "warm cache",
       parent_rss_before_fork,
     )
puts format(
       "%s posts, %.1f MiB through %d workers in %.1fs (%s posts/s, %.2f MiB/s aggregate)",
       number(sum.call("posts")),
       sum.call("bytes") / 1024.0 / 1024,
       ok.size,
       elapsed,
       number((sum.call("posts") / elapsed).round),
       sum.call("bytes") / 1024.0 / 1024 / elapsed,
     )
puts format(
       "Engine tier: %s posts (%.1f%%), %.1f MiB (%.1f%%); scan calls %s " \
         "(%s live, %s batched), %.1fs in V8; trials %s",
       number(sum.call("engine_posts")),
       100.0 * sum.call("engine_posts") / sum.call("posts"),
       sum.call("engine_bytes") / 1024.0 / 1024,
       100.0 * sum.call("engine_bytes") / sum.call("bytes"),
       number(sum.call("scan_calls")),
       number(sum.call("live_scans")),
       number(sum.call("batch_scans")),
       sum.call("scan_seconds"),
       number(sum.call("scan_calls") - sum.call("live_scans") - sum.call("batch_scans")),
     )
puts format(
       "Embeds: %s rows across %s posts; resolve %.1fs",
       number(sum.call("embed_rows")),
       number(sum.call("written_posts")),
       sum.call("resolve_seconds"),
     )

refusals = Hash.new(0)
unresolved = Hash.new(0)
ok.each do |result|
  (result["refusals"] || {}).each { |cause, count| refusals[cause] += count }
  (result["unresolved"] || {}).each { |kind, count| unresolved[kind] += count }
end
puts "Refusals: #{refusals.empty? ? "none" : refusals.map { |cause, count| "#{cause} #{number(count)}" }.join(", ")}"
if options[:log_refusals] > 0
  ok.each do |result|
    (result["refusal_samples"] || {}).each do |cause, ids|
      puts "  worker #{result["worker"]} #{cause}: posts #{ids.join(", ")}"
    end
  end
end
puts "Unresolved embeds (#{options[:round_trip]}): " +
       (
         if unresolved.empty?
           "none"
         else
           unresolved.map { |kind, count| "#{kind} #{number(count)}" }.join(", ")
         end
       )
puts "Orphan placeholders: #{number(sum.call("orphans"))}"

puts "\nPer worker:"
ok.each do |result|
  pss = result["pss_end"] ? format(", pss %.1f", result["pss_end"]) : ""
  puts format(
         "  #%d  %s posts  ctx init %.2fs  rss %.1f -> %.1f -> %.1f MiB%s",
         result["worker"],
         number(result["posts"]),
         result["context_init_seconds"],
         result["rss_before_context"],
         result["rss_after_context"],
         result["rss_end"],
         pss,
       )
end

violations = sum.call("violations")
if options[:round_trip] == "identity-hit"
  puts format(
         "\nIdentity-hit: %s expected rewrites (quote/link/hashtag/mention hits), %s violations",
         number(sum.call("expected_rewrites")),
         number(violations),
       )
else
  puts format(
         "\nAll-miss round-trip: %s violations " \
           "(%s deterministic site-link origin rewrites verified byte-exactly)",
         number(violations),
         number(sum.call("site_rewrites")),
       )
end

if violations > 0
  puts "VIOLATIONS — the round-trip contract is broken; samples:"
  ok.each do |result|
    Array(result["violation_samples"]).each do |sample|
      puts "  post #{sample["id"]} first diff at byte #{sample["byte"]}"
      puts "    expected: #{sample["expected"]}"
      puts "    actual:   #{sample["actual"]}"
    end
  end
end

exit(1) if violations > 0 || failed.any?
puts "\nOK"
