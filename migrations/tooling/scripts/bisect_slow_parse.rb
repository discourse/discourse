# frozen_string_literal: true

# Shrinks a post body that makes the markdown engine parse catastrophically
# slow down to a minimal region that still triggers the slowdown — the input
# an upstream markdown-it / discourse-markdown-it bug report needs, and the
# shape a cheap pre-parse guard would have to recognize.
#
# A body that outruns the extraction's fast ceiling is a `--dump-refusals`
# artifact from `validate_markdown_extraction.rb` (an `engine_error-<id>.md`
# file). Feed one here:
#
#   cd migrations/converters
#   bundle exec ruby ../tooling/scripts/bisect_slow_parse.rb \
#     ../../tmp/refusal-bodies/engine_error-59019.md
#
# The engine context needs no Rails, so this runs under the converters bundle
# alone. `--probe-timeout MS` (default 1000) is the ceiling a candidate must
# outrun to count as slow: low enough that the minimal region terminates it,
# high enough that ordinary parsing does not. `--forum-host HOST` mirrors the
# converter's internal-host config, in case the slowdown needs it (repeatable).
#
# The reduction is deterministic and fail-closed toward a larger region: a
# candidate that parses within the ceiling is treated as not-slow, so the
# result is always a region that genuinely reproduces. Some pathologies need
# the whole body (a global O(n^2) with no small trigger); the tool reports the
# smallest region it could still reproduce with and says when that is the
# whole input.

require "optparse"

options = { probe_timeout: 1000, forum_hosts: [] }
OptionParser
  .new do |parser|
    parser.banner = "Usage: bisect_slow_parse.rb [options] BODY_FILE"
    parser.on("--probe-timeout MS", Integer, "Slow-if-exceeded ceiling (default 1000)") do |v|
      options[:probe_timeout] = v
    end
    parser.on("--forum-host HOST", "Source forum host, repeatable") do |v|
      options[:forum_hosts] << v
    end
  end
  .parse!

body_file = ARGV.first
abort("a body file is required (a --dump-refusals artifact)") if body_file.nil?
abort("no such file: #{body_file}") unless File.file?(body_file)

require "migrations-converters"

$stdout.sync = true

MarkdownEngine = Migrations::Converters::MarkdownEngine

# A diagnostic must terminate even on an awkward pathology: past this many
# probes the search stops and reports the smallest slow region found so far.
MAX_PROBES = 600

def monotonic_time
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# A terminated context is left in an indeterminate state and cannot be reused,
# so a probe that hits the ceiling disposes and the next one rebuilds; a probe
# that parses in time keeps its context for the next candidate. Building the
# context evaluates the whole engine bundle, so reuse across the many
# fast-enough probes a shrink makes keeps a run to seconds, not minutes.
class SlowProbe
  attr_reader :probes

  def initialize(bundle, config, timeout_ms)
    @bundle = bundle
    @config = config
    @timeout_ms = timeout_ms
    @probes = 0
    @context = nil
  end

  def budget_left?
    @probes < MAX_PROBES
  end

  def slow?(body)
    @probes += 1
    @context ||=
      MarkdownEngine::Context.new(bundle: @bundle, config: @config, timeout_ms: @timeout_ms)
    @context.scan([{ id: 1, raw: body }])
    false
  rescue MiniRacer::ScriptTerminatedError, MiniRacer::RuntimeError
    # V8's timeout does not always preempt a catastrophic parse promptly (the
    # cost is in C++ regex/balancing, which checks the interrupt rarely), so a
    # slow probe can run well past the ceiling — the same reason these bodies
    # burn their whole retry ceiling in a real run.
    @context&.close
    @context = nil
    true
  end

  def close
    @context&.close
    @context = nil
  end
end

bundle = MarkdownEngine::Bundle.load_or_build
config =
  MarkdownEngine::Config.new(
    source_settings: options[:forum_hosts].any? ? { "enable_markdown_linkify" => true } : {},
  )
probe = SlowProbe.new(bundle, config, options[:probe_timeout])

body = File.binread(body_file)
puts "Body: #{body_file} (#{body.bytesize} bytes)"
puts "Probe ceiling: #{options[:probe_timeout]} ms"

unless probe.slow?(body)
  puts "\nThe whole body parses within the ceiling — not reproduced."
  puts "Lower --probe-timeout, or this body is no longer slow with this config."
  exit(1)
end
puts "Whole body is slow (parse terminated at the ceiling). Shrinking...\n\n"

# The largest cut that keeps the region slow, found by binary search over the
# cut length: the smallest kept-length that is still slow. `keep` maps a
# kept-length to the candidate region (a prefix, or a suffix). Fail-closed: the
# binary search only accepts a shorter region that reproduces, so the returned
# region is always slow.
def minimal_end(region, probe, label)
  low = 1
  high = region.bytesize
  best = region
  while low < high
    mid = (low + high) / 2
    candidate = yield(region, mid)
    if probe.slow?(candidate)
      best = candidate
      high = mid
    else
      low = mid + 1
    end
  end
  puts "  #{label}: #{region.bytesize} -> #{best.bytesize} bytes" if best.bytesize < region.bytesize
  best
end

region = body
while probe.budget_left?
  before = region.bytesize
  # Shrink from the right (keep a prefix), then from the left (keep a suffix).
  region = minimal_end(region, probe, "trim tail") { |r, len| r.byteslice(0, len) }
  region = minimal_end(region, probe, "trim head") { |r, len| r.byteslice(r.bytesize - len, len) }
  break if region.bytesize == before
end

# A final pass removing an interior chunk, for a pathology whose trigger is not
# at either edge; narrowing the window until no single removal keeps it slow.
window = region.bytesize / 2
while window >= 1 && probe.budget_left?
  shrank = false
  offset = 0
  while offset + window < region.bytesize && probe.budget_left?
    candidate = region.byteslice(0, offset) + region.byteslice(offset + window..)
    if probe.slow?(candidate)
      region = candidate
      shrank = true
    else
      offset += window
    end
  end
  window /= 2 unless shrank
end

puts "  probe budget exhausted; reporting smallest region found" unless probe.budget_left?

puts "\nMinimal slow region: #{region.bytesize} bytes (#{probe.probes} probes)"
if region.bytesize == body.bytesize
  puts "The pathology needs the whole body — no smaller region reproduces it."
else
  puts "Snippet (inspect for the pathological shape):"
  puts region.length > 300 ? "#{region.byteslice(0, 300).inspect} …" : region.inspect
end

probe.close

minimal_path = "#{body_file.sub(/\.md\z/, "")}.minimal.md"
File.binwrite(minimal_path, region)
puts "\nWritten to #{minimal_path}"
