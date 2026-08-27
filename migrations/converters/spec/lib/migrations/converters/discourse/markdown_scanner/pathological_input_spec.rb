# frozen_string_literal: true

# Adversarial bodies from the scanner review: repeated malformed construct
# openers once made the detector regexes re-scan their whole tail per opener,
# so a single generated post could pin a conversion worker for minutes. The
# detector patterns are bounded now (line-bounded classes, atomic groups,
# length caps), and these bodies cost a fraction of a second.
#
# This spec only pins termination within a generous ceiling: a regression back
# to the old quadratic detectors blows past it by orders of magnitude (it
# measured in minutes), while the bounded patterns plus the engine parse stay
# around half a second combined. Growth-ratio and wall-clock scaling live in
# `migrations/tooling/scripts/benchmarks/markdown_extraction_scaling.rb`,
# where sizes, ratios and GC state can be reported instead of asserted
# against CI noise.
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
