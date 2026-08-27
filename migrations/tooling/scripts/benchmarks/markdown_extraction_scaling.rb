# frozen_string_literal: true

# Scaling measurements for markdown extraction that don't belong in RSpec:
# wall-clock growth ratios flake under CI noise, so they are reported here
# instead of asserted. Three families:
#
#   malformed  - repeated unclosed construct openers (the scanner review's
#                adversarial bodies); growth beyond ~linear means a detector
#                pattern lost its bounds
#   values     - many DISTINCT tracked mentions/links in mapped paragraphs;
#                growth beyond ~linear means certification regressed toward
#                O(values × body)
#   table      - many distinct mentions in table rows, whose inline blocks
#                carry no line maps, so every value is certified against the
#                whole body; the one-walk occurrence index keeps this linear
#
# Usage (from the repo root, under the converters bundle):
#
#   cd migrations/converters
#   bundle exec ruby ../tooling/scripts/benchmarks/markdown_extraction_scaling.rb
#
# The engine parse itself is not linear in bracket-dense input — that cost is
# what the destination site pays to cook the same body — so ratios here are
# indicative, not exact. Each size runs once after a warmup.

require "migrations-converters"

SIZES = [1_000, 2_000, 4_000].freeze

def build_extractor(mention_names)
  bundle = Migrations::Converters::MarkdownEngine::Bundle.load_or_build
  config = Migrations::Converters::MarkdownEngine::Config.new
  engine = Migrations::Converters::MarkdownEngine::Context.new(bundle:, config:)
  normalized = mention_names.map { |name| Migrations::NameNormalizer.normalize(name) }
  buffer =
    Migrations::Converters::EmbedBuffer.new(
      owner_type: Migrations::Database::IntermediateDB::Enums::EmbedOwner::POST,
    )
  extractor =
    Migrations::Converters::Discourse::RawExtractor.new(
      embeds: buffer,
      markdown_engine: engine,
      mention_names: Migrations::CompactStringSet.new(normalized),
      hashtag_names: Migrations::CompactStringSet.new([]),
      internal_link_hosts: {
        "forum.example.com" => nil,
      },
    )
  [extractor, buffer, engine]
end

def measure(label, extractor, buffer, body)
  buffer.clear
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  extractor.extract(body)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  puts format(
         "  %-12s %8d bytes %10.1f ms  refusals=%s",
         label,
         body.bytesize,
         elapsed * 1000,
         extractor.engine_refusals,
       )
  elapsed
end

puts "malformed openers (per fragment, repeats: #{SIZES.join(", ")})"
extractor, buffer, engine = build_extractor(%w[x])
[
  "[quote=x",
  "![x](upload://a",
  "![x](/uploads/original/2X/ab/",
  "[f|attachment](upload://a",
].each do |fragment|
  extractor.extract(fragment * 50)
  puts " #{fragment.inspect}"
  SIZES.each { |size| measure("#{size}x", extractor, buffer, fragment * size) }
end
engine.close

puts "\ndistinct values in mapped paragraphs"
extractor, buffer, engine = build_extractor((1..SIZES.max).map { |i| "user#{i}" })
extractor.extract("warmup @user1")
SIZES.each do |size|
  body = +""
  (1..size).each do |i|
    body << "para @user#{i} says [t#{i}](https://forum.example.com/t/slug-#{i}/#{i}) ok\n\n"
  end
  measure("#{size} values", extractor, buffer, body)
end
engine.close

puts "\ndistinct values in table rows (mapless inline blocks)"
extractor, buffer, engine = build_extractor((1..SIZES.max).map { |i| "user#{i}" })
extractor.extract("warmup @user1")
SIZES.each do |size|
  body = +"| who | what |\n| --- | --- |\n"
  (1..size).each { |i| body << "| @user#{i} | row #{i} |\n" }
  measure("#{size} rows", extractor, buffer, body)
end
engine.close
