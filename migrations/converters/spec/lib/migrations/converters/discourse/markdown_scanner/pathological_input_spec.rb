# frozen_string_literal: true

# Adversarial bodies from the scanner review: repeated malformed construct
# openers once made the detector regexes re-scan their whole tail per opener,
# so doubling the input quadrupled the time — and a single generated post
# could pin a conversion worker for minutes. The detector patterns are bounded
# (line-bounded classes, atomic groups, length caps), which makes a failing
# candidate cost O(1); the growth-ratio spec pins that on an input the gate
# routes to the prose walk, where only our own machinery runs.
#
# The bracket-soup inputs contain link syntax, so the gate routes them to the
# engine tier — there the dominant cost is the discourse-markdown-it parse
# itself, the exact cost the target site pays to cook the same body. Our
# machinery around the parse stays linear (no expected constructs means no
# certification work), so those inputs get an absolute ceiling instead of a
# growth ratio we don't control.
#
# Timing in CI is noisy, so the assertions are deliberately loose: input
# growing 4x may cost at most 10x (quadratic growth would cost ~16x), small
# measurements are floored, and every measurement takes the best of three
# runs. A regression back to the old quadratic detectors blows past all of
# that (it measured in minutes).
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  def measure(raw)
    3
      .times
      .map do
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        extract(raw)
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      end
      .min
  end

  def expect_near_linear(fragment)
    extract(fragment * 100) # warmup: allocations, regex compilation

    small = [measure(fragment * 2_000), 0.005].max
    large = measure(fragment * 8_000)

    expect(large).to be < small * 10
    expect(large).to be < 8.0
  end

  it "scans repeated unclosed quote openers in near-linear time on the prose walk" do
    expect_near_linear("[quote=x")
  end

  %w[![x](upload://a ![x](/uploads/original/2X/ab/ [f|attachment](upload://a].each do |fragment|
    it "keeps repeated unclosed #{fragment[0, 12]}… openers under the engine-tier ceiling" do
      extract(fragment * 100) # warmup

      expect(measure(fragment * 8_000)).to be < 8.0
    end
  end
end
