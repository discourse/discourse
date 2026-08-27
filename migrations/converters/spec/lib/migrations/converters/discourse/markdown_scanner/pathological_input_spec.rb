# frozen_string_literal: true

# Adversarial bodies from the scanner review: repeated malformed construct
# openers once made the detector regexes re-scan their whole tail per opener,
# so doubling the input quadrupled the time — and a single generated post
# could pin a conversion worker for minutes. The detector patterns are bounded
# (line-bounded classes, atomic groups, length caps), which makes a failing
# candidate cost O(1), and the engine parse these bodies route to is the exact
# cost the target site pays to cook the same body — linear in either case.
#
# Every adversarial body routes to the engine tier, where the dominant cost
# is the discourse-markdown-it parse itself — the exact cost the target site
# pays to cook the same body, and not linear in bracket-dense input. So each
# body gets an absolute ceiling rather than a growth ratio we don't control:
# a regression back to the old quadratic detectors blows past it by orders of
# magnitude (it measured in minutes), while engine cost plus our bounded
# patterns stay well under it. Every measurement takes the best of three runs
# to shrug off CI noise.
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

  [
    "[quote=x",
    "![x](upload://a",
    "![x](/uploads/original/2X/ab/",
    "[f|attachment](upload://a",
  ].each do |fragment|
    it "keeps repeated unclosed #{fragment[0, 12]}… openers under the engine-tier ceiling" do
      extract(fragment * 100) # warmup: allocations, regex compilation

      expect(measure(fragment * 8_000)).to be < 8.0
    end
  end
end
