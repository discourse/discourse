# frozen_string_literal: true

# Measures how a Discourse posts corpus would distribute across the planned
# markdown-scanner tiers:
#
#   tier 0 - no candidate construct at all: post is never scanned
#   tier 1 - candidates, but no context-sensitive syntax: plain regex
#            extraction is exact
#   tier 2 - candidates plus syntax that makes context matter (code, escapes,
#            HTML, CR line endings, link syntax): needs the real markdown-it
#            engine
#
# The tier 2 fraction determines how often the engine would run, so this
# report answers whether the tiered design meets throughput goals before any
# engine integration is built.
#
# Usage (from the repo root, under the converters bundle):
#
#   cd migrations/converters
#   bundle exec ruby ../tooling/scripts/markdown_tier_stats.rb \
#     --dbname discourse --forum-host forum.example.com
#
# Connects through the local unix socket by default; pass --db-host/--db-port/
# --db-user for TCP. --forum-host is repeatable and enables the internal-link
# candidate; without it, link candidates are not counted (noted in the report).

require "optparse"
require "pg"

options = {
  dbname: nil,
  db_host: nil,
  db_port: nil,
  db_user: nil,
  forum_hosts: [],
  batch_size: 5_000,
  limit: nil,
  filter_names: false,
}

OptionParser
  .new do |parser|
    parser.on("--dbname NAME", "Discourse database name (required)") { |v| options[:dbname] = v }
    parser.on("--db-host HOST", "Database host (default: unix socket)") do |v|
      options[:db_host] = v
    end
    parser.on("--db-port PORT", Integer, "Database port") { |v| options[:db_port] = v }
    parser.on("--db-user USER", "Database user") { |v| options[:db_user] = v }
    parser.on("--forum-host HOST", "Source forum host, repeatable") do |v|
      options[:forum_hosts] << v
    end
    parser.on("--batch-size N", Integer, "Rows per query (default 5000)") do |v|
      options[:batch_size] = v
    end
    parser.on("--limit N", Integer, "Stop after N posts (for quick runs)") do |v|
      options[:limit] = v
    end
    parser.on(
      "--filter-names",
      "Also report tiers with mentions/hashtags/emoji checked against the DB name sets",
    ) { options[:filter_names] = true }
  end
  .parse!

abort("--dbname is required") if options[:dbname].nil?

# Candidate patterns approximate core's boundary rules: mentions/hashtags only
# fire after whitespace/punctuation, so a word character before `@`/`#`
# (e.g. an email address) is not a candidate. `&` is excluded before `#` to
# skip numeric character entities.
MENTION_RE = /(?<![a-zA-Z0-9_])@[a-zA-Z0-9_]/
HASHTAG_RE = /(?<![a-zA-Z0-9_&])#[a-zA-Z0-9_\-]/
EMOJI_RE = /:[a-z0-9_+\-]+:/
INDENT_RE = /^(?: {4}|\t)/
BBCODE_CODE_RE = /\[code\]/i
# Entity decoding runs before core's text post-processing, so `&#64;bob` can
# become a mention with no literal `@` in the raw. Only entities that decode
# to a construct-relevant character (trigger or name character) matter for
# detection, though — `&#8217;` (a typographic apostrophe) cannot create or
# hide a construct. Numeric forms are decoded and tested; of the named
# aliases only the construct-relevant ones are listed here, a production gate
# should test against the full entity table.
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

# Name-capture variants for --filter-names; approximations of core's
# name syntax, checked against the database name sets.
MENTION_NAME_RE = /(?<![a-zA-Z0-9_])@([a-zA-Z0-9_][a-zA-Z0-9_.\-]*)/
HASHTAG_NAME_RE = /(?<![a-zA-Z0-9_&])#([a-zA-Z0-9\-_]+)/
EMOJI_NAME_RE = /:([a-z0-9_+\-]+):/

CANDIDATES = {
  mention: ->(raw) { MENTION_RE.match?(raw) },
  hashtag: ->(raw) { HASHTAG_RE.match?(raw) },
  emoji: ->(raw) { EMOJI_RE.match?(raw) },
  quote: ->(raw) { raw.include?("[quote") },
  upload: ->(raw) { raw.include?("upload://") },
  uploads_path: ->(raw) { raw.include?("/uploads/") },
  entity: ENTITY_RELEVANT,
}.freeze

# Constructs that core suppresses inside links; only these make link syntax a
# danger (scenario B).
LINK_SENSITIVE_CANDIDATES = %i[mention hashtag emoji].freeze

DANGERS = {
  backtick: ->(raw) { raw.include?("`") },
  backslash: ->(raw) { raw.include?("\\") },
  html: ->(raw) { raw.include?("<") },
  cr: ->(raw) { raw.include?("\r") },
  tilde_fence: ->(raw) { raw.include?("~~~") },
  indent: ->(raw) { INDENT_RE.match?(raw) },
  bbcode_code: ->(raw) { BBCODE_CODE_RE.match?(raw) },
  link_syntax: ->(raw) { raw.include?("](") || raw.include?("]:") || raw.include?("][") },
  entity: ENTITY_RELEVANT,
}.freeze

class Stats
  TIERS = [0, 1, 2].freeze

  attr_reader :posts, :bytes

  def initialize
    @posts = 0
    @bytes = 0
    @tier_posts = Hash.new(0)
    @tier_bytes = Hash.new(0)
    @tier2b_posts = 0
    @tier2b_bytes = 0
    @candidate_posts = Hash.new(0)
    @danger_posts = Hash.new(0)
    @sole_danger_posts = Hash.new(0)
    @tier2_candidate_posts = Hash.new(0)
    @tier2_candidate_bytes = Hash.new(0)
    @tier2_sole_candidate_posts = Hash.new(0)
    @tier2_sole_candidate_bytes = Hash.new(0)
  end

  def record(raw, candidates, dangers)
    size = raw.bytesize
    @posts += 1
    @bytes += size

    tier =
      if candidates.empty?
        0
      elsif dangers.empty?
        1
      else
        2
      end
    @tier_posts[tier] += 1
    @tier_bytes[tier] += size

    candidates.each { |c| @candidate_posts[c] += 1 }
    return if tier != 2

    dangers.each { |d| @danger_posts[d] += 1 }
    @sole_danger_posts[dangers.first] += 1 if dangers.size == 1

    candidates.each do |c|
      @tier2_candidate_posts[c] += 1
      @tier2_candidate_bytes[c] += size
    end
    if candidates.size == 1
      @tier2_sole_candidate_posts[candidates.first] += 1
      @tier2_sole_candidate_bytes[candidates.first] += size
    end

    dangers_b = dangers
    dangers_b = dangers - [:link_syntax] if (candidates & LINK_SENSITIVE_CANDIDATES).empty?
    if dangers_b.any?
      @tier2b_posts += 1
      @tier2b_bytes += size
    end
  end

  def report(forum_hosts, elapsed)
    line = ->(label, count, byte_count) do
      row = format("  %-28s %12s posts %6.2f%%", label, number(count), percent(count, @posts))
      row << format("   %10s %6.2f%%", mib(byte_count), percent(byte_count, @bytes)) if byte_count
      row << "\n"
    end

    out = +""
    out << format(
      "Scanned %s posts, %s in %.1fs (%s posts/s, %.1f MiB/s)\n\n",
      number(@posts),
      mib(@bytes),
      elapsed,
      number((@posts / elapsed).round),
      @bytes / elapsed / 1024 / 1024,
    )

    out << "Tiers (scenario A: every danger feature counts)\n"
    TIERS.each { |t| out << line.call("tier #{t}", @tier_posts[t], @tier_bytes[t]) }
    out << "\nScenario B: link syntax only endangers mentions/hashtags/emoji\n"
    out << line.call("tier 2", @tier2b_posts, @tier2b_bytes)

    out << "\nCandidate prevalence (posts containing each construct)\n"
    CANDIDATES.each_key { |c| out << line.call(c.to_s, @candidate_posts[c], nil) }
    if forum_hosts.any?
      out << line.call("host_link", @candidate_posts[:host_link], nil)
    else
      out << "  host_link                    (no --forum-host given, not counted)\n"
    end

    out << "\nCandidate prevalence among tier 2 (what sends posts/bytes to the engine)\n"
    @tier2_candidate_bytes
      .sort_by { |_, byte_count| -byte_count }
      .each { |c, byte_count| out << line.call(c.to_s, @tier2_candidate_posts[c], byte_count) }

    out << "\nSole candidate among tier 2 (handling only this construct off-engine would remove)\n"
    @tier2_sole_candidate_bytes
      .sort_by { |_, byte_count| -byte_count }
      .each { |c, byte_count| out << line.call(c.to_s, @tier2_sole_candidate_posts[c], byte_count) }

    out << "\nDanger prevalence among tier 2 posts\n"
    DANGERS.each_key { |d| out << line.call(d.to_s, @danger_posts[d], nil) }

    out << "\nSole danger (dropping this feature demotes the post to tier 1)\n"
    @sole_danger_posts
      .sort_by { |_, count| -count }
      .each { |d, count| out << line.call(d.to_s, count, nil) }
    out
  end

  private

  def number(value)
    value.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end

  def percent(value, total)
    total > 0 ? value * 100.0 / total : 0.0
  end

  def mib(byte_count)
    format("%.1f MiB", byte_count / 1024.0 / 1024.0)
  end
end

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

candidates = CANDIDATES.dup
if options[:forum_hosts].any?
  hosts = options[:forum_hosts]
  candidates[:host_link] = ->(raw) { hosts.any? { |host| raw.include?(host) } }
end

filtered_candidates = nil
if options[:filter_names]
  load_set = ->(sql) do
    connection.exec(sql).column_values(0).each_with_object(Set.new) { |n, set| set << n.downcase }
  end
  mentionable =
    load_set.call("SELECT username_lower FROM users") + load_set.call("SELECT name FROM groups")
  hashtag_names =
    load_set.call("SELECT slug FROM categories") + load_set.call("SELECT name FROM tags")
  emoji_names = load_set.call("SELECT name FROM custom_emojis")

  # Core trims trailing punctuation from a candidate name before lookup; one
  # trimmed retry approximates that.
  any_known = ->(raw, regex, names) do
    raw
      .scan(regex)
      .any? do |(name)|
        name = name.downcase
        names.include?(name) || names.include?(name.sub(/[._\-]+\z/, ""))
      end
  end

  filtered_candidates =
    candidates.merge(
      mention: ->(raw) do
        MENTION_RE.match?(raw) && any_known.call(raw, MENTION_NAME_RE, mentionable)
      end,
      hashtag: ->(raw) do
        HASHTAG_RE.match?(raw) && any_known.call(raw, HASHTAG_NAME_RE, hashtag_names)
      end,
      emoji: ->(raw) { EMOJI_RE.match?(raw) && any_known.call(raw, EMOJI_NAME_RE, emoji_names) },
    )
end

stats = Stats.new
filtered_stats = Stats.new if filtered_candidates
started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
last_id = 0
remaining = options[:limit]

loop do
  batch_size = options[:batch_size]
  batch_size = [batch_size, remaining].min if remaining
  break if batch_size == 0

  result =
    connection.exec_params(
      "SELECT id, raw FROM posts WHERE id > $1 ORDER BY id LIMIT $2",
      [last_id, batch_size],
    )
  break if result.ntuples == 0

  result.each do |row|
    last_id = row["id"]
    raw = row["raw"]
    next if raw.nil? || raw.empty?
    raw = raw.scrub unless raw.valid_encoding?

    found_candidates = candidates.filter_map { |name, check| name if check.call(raw) }
    found_dangers =
      if found_candidates.empty?
        []
      else
        DANGERS.filter_map { |name, check| name if check.call(raw) }
      end
    stats.record(raw, found_candidates, found_dangers)

    if filtered_stats
      kept =
        found_candidates.filter do |name|
          check = filtered_candidates[name]
          check == candidates[name] || check.call(raw)
        end
      filtered_stats.record(raw, kept, found_dangers)
    end
  end
  row_count = result.ntuples
  result.clear

  remaining -= row_count if remaining
  if stats.posts % 100_000 < options[:batch_size]
    warn("  ... #{stats.posts} posts") if stats.posts >= 100_000
  end
end

elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
puts "=== All candidates ==="
puts stats.report(options[:forum_hosts], elapsed)
if filtered_stats
  puts "\n=== Candidates filtered against DB name sets (mentions/hashtags/emoji) ==="
  puts filtered_stats.report(options[:forum_hosts], elapsed)
end
