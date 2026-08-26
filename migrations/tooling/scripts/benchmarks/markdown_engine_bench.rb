# frozen_string_literal: true

# Phase-1 benchmark for the tiered markdown-scanner design: measures what
# extracting references from tier-2 posts (candidates + context-sensitive
# syntax) costs per approach, on a sample from a real corpus:
#
#   ruby-scanner   the current MarkdownScanner-based RawExtractor
#   cook           full PrettyText.cook, the intentionally expensive ceiling
#   parse          engine parse-only + token walk in V8, one post per call
#   parse-batch-N  same, N posts per V8 call
#   bijection      count-matching on the parse results; its refusal rate says
#                  how often the proposed production path (parse-batched +
#                  bijection) would need the exact fallback
#
# Usage (from the repo root; needs the Rails app, so run under the root bundle
# with the migrations group installed — `BUNDLE_WITH=migrations bundle install`
# once if needed):
#
#   RAILS_ENV=test BUNDLE_WITH=migrations bundle exec ruby \
#     migrations/tooling/scripts/benchmarks/markdown_engine_bench.rb \
#     --dbname discourse --forum-host forum.example.com
#
# Reads the corpus database read-only over the local unix socket by default
# (--db-host/--db-port/--db-user for TCP). The Rails side boots against the
# test database and is only used for its PrettyText context.

require "optparse"

options = {
  dbname: nil,
  db_host: nil,
  db_port: nil,
  db_user: nil,
  forum_hosts: [],
  sample: 2_000,
  cook_sample: 500,
  any_tier: false,
  rails_env: "test",
  debug_refusals: 0,
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
    parser.on("--sample N", Integer, "Tier-2 posts to sample (default 2000)") do |v|
      options[:sample] = v
    end
    parser.on("--cook-sample N", Integer, "Posts for the cook ceiling (default 500)") do |v|
      options[:cook_sample] = v
    end
    parser.on("--any-tier", "Sample any non-empty post (smoke testing on tiny DBs)") do
      options[:any_tier] = true
    end
    parser.on(
      "--debug-refusals N",
      Integer,
      "Print details for the first N posts the bijection refuses",
    ) { |v| options[:debug_refusals] = v }
    parser.on(
      "--rails-env ENV",
      "Rails environment to boot PrettyText from (default test); " \
        "its database must be migrated",
    ) { |v| options[:rails_env] = v }
  end
  .parse!

abort("--dbname is required") if options[:dbname].nil?

# Gate patterns, kept in sync with ../markdown_tier_stats.rb by hand — the
# measurement scripts stay standalone instead of sharing a half-library.
MENTION_RE = /(?<![a-zA-Z0-9_])@[a-zA-Z0-9_]/
HASHTAG_RE = /(?<![a-zA-Z0-9_&])#[a-zA-Z0-9_\-]/
EMOJI_RE = /:[a-z0-9_+\-]+:/
INDENT_RE = /^(?: {4}|\t)/
BBCODE_CODE_RE = /\[code\]/i
ENTITY_RE = /&#?[a-zA-Z0-9]{1,32};/
# Mirrored from ../markdown_tier_stats.rb: only entities that can decode into
# a construct-relevant character can create or hide a construct; typographic
# entities in pasted content cannot.
ENTITY_CONSTRUCT_CHAR = /[0-9A-Za-z_@#:.\-]/
ENTITY_NUMERIC_RE = /&#(x\h{1,6}|\d{1,7});/i
ENTITY_NAMED_RE = /&(?:commat|num|colon|period|lowbar);/
ENTITY_RELEVANT = ->(raw) do
  return false unless raw.include?("&")
  return true if ENTITY_NAMED_RE.match?(raw)
  raw
    .scan(ENTITY_NUMERIC_RE)
    .any? do |(code)|
      codepoint = code.start_with?("x", "X") ? code[1..].to_i(16) : code.to_i
      codepoint < 128 && ENTITY_CONSTRUCT_CHAR.match?(codepoint.chr)
    end
end

CANDIDATE_CHECKS = [
  ->(raw) { MENTION_RE.match?(raw) },
  ->(raw) { HASHTAG_RE.match?(raw) },
  ->(raw) { EMOJI_RE.match?(raw) },
  ->(raw) { raw.include?("[quote") },
  ->(raw) { raw.include?("upload://") },
  ->(raw) { raw.include?("/uploads/") },
  ENTITY_RELEVANT,
].freeze

DANGER_CHECKS = [
  ->(raw) { raw.include?("`") },
  ->(raw) { raw.include?("\\") },
  ->(raw) { raw.include?("<") },
  ->(raw) { raw.include?("\r") },
  ->(raw) { raw.include?("~~~") },
  ->(raw) { INDENT_RE.match?(raw) },
  ->(raw) { BBCODE_CODE_RE.match?(raw) },
  ->(raw) { raw.include?("](") || raw.include?("]:") || raw.include?("][") },
  ->(raw) { ENTITY_RE.match?(raw) },
].freeze

def monotonic_time
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

puts "Booting Rails/PrettyText..."
boot_started_at = monotonic_time
rails_root = File.expand_path("../../../..", __dir__)
ENV["RAILS_ENV"] = options[:rails_env]
# Single-threaded script; Discourse resolves autoload-ignore paths and the
# markdown asset glob relative to the cwd, so boot must happen at the app root
# (same reasoning as the migrations spec_setup boot).
# rubocop:disable Discourse/NoChdir
begin
  Dir.chdir(rails_root) do
    require File.join(rails_root, "config", "environment")
    # The first cook builds the markdown pipeline (with a cwd-relative asset
    # glob) and leaves the engine instance `__pt` in the context; every later
    # arm reuses that engine the way a converter worker would.
    PrettyText.cook("warm up @user `code` #tag :smile:")
  end
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError => e
  abort(<<~MESSAGE)
    Booting PrettyText failed: #{e.message.lines.first}
    The Rails #{options[:rails_env]} database is probably missing or not
    migrated (the warm-up cook queries it for emoji/hashtag data). Fix with

      RAILS_ENV=#{options[:rails_env]} bin/rake db:create db:migrate

    or pass --rails-env development to boot from an already-migrated
    development database.
  MESSAGE
end
# rubocop:enable Discourse/NoChdir
require "migrations-converters"
require "pg"
boot_seconds = monotonic_time - boot_started_at

corpus =
  PG::Connection.new(
    {
      dbname: options[:dbname],
      host: options[:db_host],
      port: options[:db_port],
      user: options[:db_user],
    }.compact,
  )

# --- corpus name sets, for the Ruby scanner arm and the JS-side filtering ---

def load_names(corpus, sql)
  corpus.exec(sql).column_values(0)
end

mention_names =
  load_names(corpus, "SELECT username FROM users") + load_names(corpus, "SELECT name FROM groups") +
    %w[here all]
hashtag_names =
  load_names(corpus, "SELECT slug FROM categories") + load_names(corpus, "SELECT name FROM tags")
custom_emoji_names = load_names(corpus, "SELECT name FROM custom_emojis")

normalize = ->(names) { names.map { |name| Migrations::NameNormalizer.normalize(name) } }
internal_link_hosts = options[:forum_hosts].to_h { |host| [host.downcase, nil] }

EmbedOwner = Migrations::Database::IntermediateDB::Enums::EmbedOwner

extractor =
  Migrations::Converters::Discourse::RawExtractor.new(
    embeds: Migrations::Converters::EmbedBuffer.new(owner_type: EmbedOwner::POST),
    mention_names: Migrations::SortedStringSet.new(normalize.call(mention_names)),
    hashtag_names: Migrations::SortedStringSet.new(normalize.call(hashtag_names)),
    custom_emoji_names: custom_emoji_names.empty? ? nil : custom_emoji_names,
    internal_link_hosts:,
  )
# One buffer per extractor for the whole run: buffer rows just accumulate, and
# per-post allocation is not what this benchmark compares.

# --- sample tier-2 posts, spread across the id range ---

def tier2?(raw, forum_hosts, any_tier)
  candidate =
    CANDIDATE_CHECKS.any? { |check| check.call(raw) } ||
      forum_hosts.any? { |host| raw.include?(host) }
  return true if any_tier && !raw.empty?
  candidate && DANGER_CHECKS.any? { |check| check.call(raw) }
end

bounds = corpus.exec("SELECT min(id), max(id) FROM posts").values.first
abort("posts table is empty") if bounds.first.nil?
min_id, max_id = bounds.map(&:to_i)
stride = [(max_id - min_id) / [options[:sample], 1].max, 0].max

posts = []
cursor = min_id - 1
while posts.size < options[:sample]
  rows =
    corpus.exec_params("SELECT id, raw FROM posts WHERE id > $1 ORDER BY id LIMIT 100", [cursor])
  break if rows.ntuples == 0

  hit = nil
  rows.each do |row|
    cursor = row["id"].to_i
    raw = row["raw"].to_s
    raw = raw.scrub unless raw.valid_encoding?
    if tier2?(raw, options[:forum_hosts], options[:any_tier])
      hit = { id: cursor, raw: }
      break
    end
  end
  next if hit.nil?

  posts << hit
  # Jumping ahead spreads the sample over the whole id range instead of
  # taking the first N matches.
  cursor += stride
end

abort("no matching posts found (try --any-tier on tiny databases)") if posts.empty?
sample_bytes = posts.sum { |post| post[:raw].bytesize }
puts format(
       "Sampled %d posts, %.1f MiB (avg %.1f KiB), boot %.1fs",
       posts.size,
       sample_bytes / 1024.0 / 1024.0,
       sample_bytes / 1024.0 / posts.size,
       boot_seconds,
     )

# --- JS scan function: engine parse + compact token walk ---

# The walk returns, per inline block, the construct values core recognized
# (mention texts, hashtag/link hrefs, image srcs) plus its line map, and the
# line maps of code/html/quote blocks — everything the bijection check needs,
# never the token tree.
PrettyText.v8.eval(<<~JS)
  function __benchWalk(children, block) {
    if (!children) return;
    for (let i = 0; i < children.length; i++) {
      const child = children[i];
      if (child.type === "mention_open") {
        const next = children[i + 1];
        if (next && next.type === "text") block.mentions.push(next.content);
      } else if (child.type === "link_open") {
        const hashtagType = child.attrGet("data-type");
        // The upload protocol rewrites unresolved short URLs into a
        // placeholder and stashes the original in data-orig-*; the original
        // is the construct.
        const href = child.attrGet("data-orig-href") || child.attrGet("href");
        if (hashtagType !== null) block.hashtags.push(href || "");
        // Fragment-only hrefs are intra-post anchors — some synthesized from
        // headings, none in need of remapping — so they are not constructs.
        else if (href !== null && href[0] !== "#") block.links.push(href);
      } else if (child.type === "image") {
        const src = child.attrGet("data-orig-src") || child.attrGet("src");
        if (src !== null) block.images.push(src);
        __benchWalk(child.children, block);
      } else if (child.type === "code_inline") {
        block.code += 1;
      } else if (child.children) {
        __benchWalk(child.children, block);
      }
    }
  }
  function __benchScanOne(raw) {
    const tokens = __pt.parse(raw);
    const blocks = [];
    const blockTokens = [];
    for (const token of tokens) {
      if (token.type === "inline") {
        const block = { map: token.map, mentions: [], hashtags: [], links: [], images: [], code: 0 };
        __benchWalk(token.children, block);
        if (
          block.mentions.length || block.hashtags.length || block.links.length ||
          block.images.length || block.code > 0
        ) {
          blocks.push(block);
        }
      } else if (
        token.map &&
        (token.type === "fence" || token.type === "code_block" ||
          token.type === "html_block" || (token.type === "bbcode_open" && token.tag === "aside"))
      ) {
        blockTokens.push({ type: token.type, map: token.map });
      }
    }
    return { blocks: blocks, blockTokens: blockTokens };
  }
  function __benchScanMany(raws) {
    return raws.map(__benchScanOne);
  }
JS

# --- bijection: count-matching on the parse results ---

# A block's engine-recognized values must appear in its raw line region exactly
# as many times as core recognized them, and the region must pass the entity
# precondition (entity decoding means a recognized value need not exist
# literally). Only then is replace-all provably safe; anything else is a
# refusal that the production path would route to the exact fallback. The
# entity precondition is evaluated both ways — strict (any entity-shaped
# sequence refuses) and narrowed (only construct-relevant entities refuse) —
# because how much the narrowing buys is one of the numbers this benchmark
# exists to produce.
class BijectionCheck
  Result =
    Struct.new(
      :mismatches,
      :entity_strict,
      :entity_narrowed,
      :details,
      :region_certified,
      :global_certified,
    ) do
      def refused_strict?
        entity_strict || mismatches.any?
      end

      def refused_narrowed?
        entity_narrowed || mismatches.any?
      end
    end

  # @param tracked [#call] whether a link/image value is one the migration
  #   remaps at all; untracked values (external links) can never refuse.
  def initialize(raw, scan, tracked:)
    # markdown-it normalizes line endings before tokenizing, so token maps
    # refer to normalized lines; index and count over the same normalization
    # or CR-bearing posts desync.
    raw = raw.gsub(/\r\n?/, "\n") if raw.include?("\r")
    @raw = raw.b
    @scan = scan
    @tracked = tracked
    @line_starts = [0]
    offset = 0
    while (offset = @raw.index("\n", offset))
      offset += 1
      @line_starts << offset
    end
  end

  def result
    mismatches = []
    details = []
    entity_strict = false
    entity_narrowed = false
    region_certified = 0
    # A value can fail its block region and still be provably safe post-wide:
    # reference-link definitions live outside every block map, so the
    # destination occurrence is only findable in the whole raw. Expected
    # counts are accumulated across all blocks and settled globally after the
    # per-region pass.
    expected_totals = Hash.new(0)
    region_failures = {}

    @scan["blocks"].each do |block|
      region = region_for(block["map"])
      next if region.nil?

      entity_strict ||= ENTITY_RE.match?(region)
      entity_narrowed ||= ENTITY_RELEVANT.call(region)
      constructs = {
        mention: [block["mentions"], true],
        link: [block["links"].filter(&@tracked), false],
        image: [block["images"].filter(&@tracked), false],
      }
      constructs.each do |construct, (values, boundary)|
        values.tally.each do |value, expected|
          key = [construct, value]
          expected_totals[key] += expected
          next if region_failures.key?(key)
          counts = candidate_counts(region, value, boundary:)
          if counts.each_value.any? { |count| count == expected }
            region_certified += 1
          else
            region_failures[key] = { excerpt: region[0, 80], region_counts: counts }
          end
        end
      end
    end

    global_certified = 0
    if region_failures.any?
      # The fallback counts over the whole raw, so entities anywhere in the
      # post can now hide or create an occurrence.
      entity_strict ||= ENTITY_RE.match?(@raw)
      entity_narrowed ||= ENTITY_RELEVANT.call(@raw)
      region_failures.each do |(construct, value), failure|
        boundary = construct == :mention
        expected = expected_totals[[construct, value]]
        global_counts = candidate_counts(@raw, value, boundary:)
        certified =
          global_counts.each_value.any? { |count| count == expected } ||
            (!boundary && reference_definition_covers?(value, global_counts, expected))
        if certified
          global_certified += 1
        else
          mismatches << construct
          details << {
            construct:,
            value:,
            expected: expected_totals[[construct, value]],
            region_counts: failure[:region_counts],
            global_counts:,
            excerpt: failure[:excerpt],
          }
        end
      end
    end

    Result.new(
      mismatches.uniq,
      entity_strict,
      entity_narrowed,
      details,
      region_certified,
      global_certified,
    )
  end

  private

  def region_for(map)
    return nil if map.nil?
    from = @line_starts[map[0]]
    return nil if from.nil?
    to = @line_starts[map[1]] || @raw.bytesize
    @raw.byteslice(from, to - from)
  end

  # Alternate readings of the same construct: the engine normalizes URLs
  # (percent-encoding, linkify adds a scheme to bare-domain autolinks), so a
  # value may exist in the raw in a different but equivalent spelling. Any
  # reading matching the expected count certifies.
  def candidate_counts(region, value, boundary:)
    if boundary
      { literal: occurrences(region, value.b, boundary: true) }
    else
      url_variants(value).transform_values do |variant|
        occurrences(region, variant, boundary: false)
      end
    end
  end

  def url_variants(value)
    value = value.b
    variants = { literal: value }
    decoded = CGI.unescape(value).b
    variants[:decoded] = decoded if decoded != value
    bare = value.sub(%r{\Ahttps?://}, "")
    variants[:schemeless] = bare if bare != value
    bare_decoded = CGI.unescape(bare).b
    variants[:schemeless_decoded] = bare_decoded if bare_decoded != bare && bare_decoded != decoded
    variants
  end

  # Several reference links can share one definition (`[a][1] ... [b][1]` with
  # one `[1]: url` line); production rewrites the single definition occurrence
  # and that covers every engine token with the value, so fewer raw
  # occurrences than engine tokens certifies — but only when at least one
  # occurrence really is a reference-definition line for exactly this URL.
  def reference_definition_covers?(value, counts, expected)
    return false unless counts.each_value.any? { |count| count > 0 && count < expected }
    url_variants(value).each_value.any? do |variant|
      @raw.match?(/^ {0,3}\[[^\]]*\]:\s*<?#{Regexp.escape(variant)}>?(?:\s|$)/)
    end
  end

  def occurrences(region, value, boundary:)
    pattern =
      if boundary
        # Core's name regex ends on a word character: a trailing `.`/`-`
        # before a non-name character is punctuation, not name, so
        # `@user.` still counts while `@sam` inside `@samuel` or `@sam.b`
        # does not.
        /#{Regexp.escape(value)}(?![a-zA-Z0-9_])(?![.\-][a-zA-Z0-9_])/
      else
        # Same two-char idea for URLs, mirroring linkify's trailing-punctuation
        # stripping: `https://x/c` inside `https://x/c/` is a different URL,
        # but `https://x/c` followed by `. ` is this one. Errors here only
        # lower counts, which refuses — fail-closed.
        %r{#{Regexp.escape(value)}(?![A-Za-z0-9/])(?![.?#&=%~_\-][A-Za-z0-9/])}
      end
    region.scan(pattern).size
  end
end

# --- measurement helpers ---

def percentile(sorted, fraction)
  sorted[[(sorted.size * fraction).ceil - 1, 0].max]
end

def run_arm(name, posts, results)
  # A short untimed pass lets JITs and caches settle so the timed pass
  # measures steady state.
  posts.first(20).each { |post| yield(post) }

  times = []
  bytes = 0
  failures = 0
  posts.each do |post|
    started_at = monotonic_time
    begin
      yield(post)
    rescue StandardError
      failures += 1
      next
    end
    times << monotonic_time - started_at
    bytes += post[:raw].bytesize
  end

  if times.empty?
    results << { name:, posts: 0, failures: }
    return
  end

  total = times.sum
  sorted = times.sort
  results << {
    name:,
    posts: times.size,
    posts_per_second: times.size / total,
    mib_per_second: bytes / total / 1024 / 1024,
    p50: percentile(sorted, 0.50),
    p95: percentile(sorted, 0.95),
    p99: percentile(sorted, 0.99),
    max: sorted.last,
    failures:,
  }
end

# Production only remaps its own constructs — forum-host URLs, site-relative
# routes, uploads. An external link with exotic normalization must not force
# a refusal, so only tracked values enter the bijection at all.
tracked_hosts = options[:forum_hosts].map(&:downcase)
tracked_value = ->(value) do
  return true if value.include?("upload://") || value.include?("/uploads/")
  return true if value.start_with?("/")
  bare = value.downcase.sub(%r{\Ahttps?://}, "")
  tracked_hosts.any? { |host| bare.start_with?(host) }
end

results = []
context = PrettyText.v8

run_arm("ruby-scanner", posts, results) { |post| extractor.extract(post[:raw]) }

run_arm("cook", posts.first(options[:cook_sample]), results) { |post| PrettyText.cook(post[:raw]) }

parse_results = {}
run_arm("parse", posts, results) do |post|
  parse_results[post[:id]] = context.call("__benchScanOne", post[:raw])
end

[32, 256].each do |batch_size|
  run_arm_name = "parse-batch-#{batch_size}"
  batches = posts.each_slice(batch_size).to_a
  # Timing whole batches: the per-post latency columns are meaningless here,
  # only throughput is comparable, so post timings are amortized evenly.
  times = []
  bytes = 0
  batches.first(2).each { |batch| context.call("__benchScanMany", batch.map { |post| post[:raw] }) }
  batches.each do |batch|
    started_at = monotonic_time
    context.call("__benchScanMany", batch.map { |post| post[:raw] })
    elapsed = monotonic_time - started_at
    batch.size.times { times << elapsed / batch.size }
    bytes += batch.sum { |post| post[:raw].bytesize }
  end
  total = times.sum
  sorted = times.sort
  results << {
    name: run_arm_name,
    posts: times.size,
    posts_per_second: times.size / total,
    mib_per_second: bytes / total / 1024 / 1024,
    p50: percentile(sorted, 0.50),
    p95: percentile(sorted, 0.95),
    p99: percentile(sorted, 0.99),
    max: sorted.last,
    failures: 0,
  }
end

run_arm("bijection", posts, results) do |post|
  scan = parse_results[post[:id]]
  BijectionCheck.new(post[:raw], scan, tracked: tracked_value).result unless scan.nil?
end

# Tallied outside run_arm so the warmup pass doesn't double-count.
mismatch_causes = Hash.new(0)
checked = 0
refused_strict = 0
refused_narrowed = 0
entity_only_strict = 0
entity_only_narrowed = 0
region_certified = 0
global_certified = 0
debug_remaining = options[:debug_refusals]
posts.each do |post|
  scan = parse_results[post[:id]]
  next if scan.nil?
  checked += 1
  result = BijectionCheck.new(post[:raw], scan, tracked: tracked_value).result
  refused_strict += 1 if result.refused_strict?
  refused_narrowed += 1 if result.refused_narrowed?
  region_certified += result.region_certified
  global_certified += result.global_certified
  if result.mismatches.any?
    result.mismatches.each { |cause| mismatch_causes[cause] += 1 }
  else
    entity_only_strict += 1 if result.entity_strict
    entity_only_narrowed += 1 if result.entity_narrowed
  end

  if result.refused_narrowed? && debug_remaining > 0
    debug_remaining -= 1
    warn "refused post #{post[:id]} (entity: #{result.entity_narrowed ? "yes" : "no"}, " \
           "cr: #{post[:raw].include?("\r") ? "yes" : "no"})"
    result.details.each do |detail|
      warn "  #{detail[:construct]} expected=#{detail[:expected]} " \
             "region=#{detail[:region_counts]} global=#{detail[:global_counts]} " \
             "value=#{detail[:value].inspect}"
      warn "    region excerpt: #{detail[:excerpt].inspect}"
    end
  end
end

puts
puts format(
       "%-16s %8s %10s %9s %8s %8s %8s %8s %6s",
       "arm",
       "posts",
       "posts/s",
       "MiB/s",
       "p50 ms",
       "p95 ms",
       "p99 ms",
       "max ms",
       "fail",
     )
results.each do |r|
  if r[:posts] == 0
    puts format("%-16s %8d  (every post failed, %d failures)", r[:name], 0, r[:failures])
    next
  end
  puts format(
         "%-16s %8d %10.0f %9.2f %8.3f %8.3f %8.3f %8.3f %6d",
         r[:name],
         r[:posts],
         r[:posts_per_second],
         r[:mib_per_second],
         r[:p50] * 1000,
         r[:p95] * 1000,
         r[:p99] * 1000,
         r[:max] * 1000,
         r[:failures],
       )
end

puts
puts "Proposed production path: parse-batch + bijection."
if checked == 0
  puts "Bijection: no parse results to check."
  exit
end
puts format("Bijection refusals (posts needing the exact fallback, of %d checked):", checked)
puts format(
       "  strict entity precondition:   %6d (%.2f%%), %d of them entity-only",
       refused_strict,
       refused_strict * 100.0 / checked,
       entity_only_strict,
     )
puts format(
       "  narrowed entity precondition: %6d (%.2f%%), %d of them entity-only",
       refused_narrowed,
       refused_narrowed * 100.0 / checked,
       entity_only_narrowed,
     )
puts format(
       "  value checks: %d region-certified, %d via whole-post fallback",
       region_certified,
       global_certified,
     )
puts "  count-mismatch causes (posts):"
mismatch_causes
  .sort_by { |_, count| -count }
  .each { |cause, count| puts format("    %-8s %6d", cause, count) }
