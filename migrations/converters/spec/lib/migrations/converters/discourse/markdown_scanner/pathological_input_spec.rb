# frozen_string_literal: true

# Adversarial bodies: repeated malformed construct openers. With unbounded
# detector patterns, each opener re-scans the whole remaining input, and a
# single generated post can occupy a conversion worker for minutes. The
# detector patterns are bounded (line-bounded classes, atomic groups, length
# caps), and these bodies cost a fraction of a second.
#
# This spec only asserts termination within a generous ceiling: a quadratic
# regression exceeds it by orders of magnitude, while the bounded patterns
# plus the engine parse stay around half a second combined. Growth ratios and
# wall-clock scaling are reported by the measurement tooling on the
# `mt/markdown-validation-tooling` branch, where sizes, ratios and GC state
# can be reported instead of asserted against CI noise.
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  let(:fragments) do
    ["[quote=x", "![x](upload://a", "![x](/uploads/original/2X/ab/", "[f|attachment](upload://a"]
  end

  it "keeps repeated unclosed openers within the engine-tier ceiling" do
    fragments.each { |fragment| extract(fragment * 50) } # warmup

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    fragments.each { |fragment| extract(fragment * 2_000) }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    expect(elapsed).to be < 10.0
  end
end
