# frozen_string_literal: true

# Adversarial bodies from the scanner review: repeated malformed construct
# openers once made the detector regexes re-scan their whole tail per opener,
# so doubling the input quadrupled the time — and a single generated post
# could pin a conversion worker for minutes. The detector patterns are now
# bounded (line-bounded classes, atomic groups, length caps), which makes a
# failing candidate cost O(1); these specs pin that with a growth-ratio check.
#
# Timing in CI is noisy, so the assertions are deliberately loose: input
# growing 4x may cost at most 10x (quadratic growth would cost ~16x), small
# measurements are floored, and every measurement takes the best of three
# runs. A regression back to quadratic blows past all of that.
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
    # The growth ratio is the real assertion; this bound only catches a
    # collapse back to super-linear at this size (which measured in minutes).
    # Adversarial bracket-dense input keeps a fat linear constant: every
    # opener still pays a capped attempt across several detectors.
    expect(large).to be < 8.0
  end

  it "scans repeated unclosed quote openers in near-linear time" do
    expect_near_linear("[quote=x")
  end

  it "scans repeated unclosed short-upload openers in near-linear time" do
    expect_near_linear("![x](upload://a")
  end

  it "scans repeated unclosed full-upload openers in near-linear time" do
    expect_near_linear("![x](/uploads/original/2X/ab/")
  end

  it "scans repeated unclosed attachment openers in near-linear time" do
    expect_near_linear("[f|attachment](upload://a")
  end
end
