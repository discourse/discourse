# frozen_string_literal: true

require "migrations-converters"

# The extractor replaces every reference in a post body with a placeholder token
# and records an embed row for it; the importer's resolver puts the tokens back.
# With nothing mapped, the two must cancel out: the resolved body equals the
# extractor's normalized input, except for links to the source site, whose
# origin always becomes the destination's base URL.
#
# The `PlaceholderResolver` specs cover the resolver alone against hand-written
# rows, so a recorder-side mistake — a wrong `url_offset`, a missing
# `original_markdown`, a token minted but never written — cannot show up there.
# It shows up here, because the rows come from a real extraction.
RSpec.describe "markdown extraction round trip" do
  include_context "with extraction round trip"

  let(:fixtures) { ExtractionRoundTrip.round_trip_bodies }

  describe "resolution with nothing mapped" do
    it "restores the #{"code".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("code"))

      expect(outcome.resolved["code"]).to eq(outcome.expected["code"])
    end

    it "restores the #{"emoji".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("emoji"))

      expect(outcome.resolved["emoji"]).to eq(outcome.expected["emoji"])
    end

    it "restores the #{"entities".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("entities"))

      expect(outcome.resolved["entities"]).to eq(outcome.expected["entities"])
    end

    it "restores the #{"hashtags".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("hashtags"))

      expect(outcome.resolved["hashtags"]).to eq(outcome.expected["hashtags"])
    end

    it "restores the #{"links".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("links"))

      expect(outcome.resolved["links"]).to eq(outcome.expected["links"])
    end

    it "restores the #{"mentions".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("mentions"))

      expect(outcome.resolved["mentions"]).to eq(outcome.expected["mentions"])
    end

    it "restores the #{"mixed".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("mixed"))

      expect(outcome.resolved["mixed"]).to eq(outcome.expected["mixed"])
    end

    it "restores the #{"multiline_label".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("multiline_label"))

      expect(outcome.resolved["multiline_label"]).to eq(outcome.expected["multiline_label"])
    end

    it "restores the #{"quotes".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("quotes"))

      expect(outcome.resolved["quotes"]).to eq(outcome.expected["quotes"])
    end

    it "restores the #{"references".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("references"))

      expect(outcome.resolved["references"]).to eq(outcome.expected["references"])
    end

    it "restores the #{"uploads".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("uploads"))

      expect(outcome.resolved["uploads"]).to eq(outcome.expected["uploads"])
    end

    it "restores the #{"mixed_crlf".tr("_", " ")} body, rewriting only source-site origins" do
      outcome = round_trip(fixtures.slice("mixed_crlf"))

      expect(outcome.resolved["mixed_crlf"]).to eq(outcome.expected["mixed_crlf"])
    end

    # Every construct the fixtures carry must survive the scanner intact;
    # otherwise the round trip above would be checking verbatim passthrough.
    it "extracts without refusing any fixture" do
      outcome = round_trip(fixtures)

      expect(outcome.refusals).to be_empty
    end

    # A fixture set that stopped producing rows would satisfy the round trip
    # with an extractor that recorded nothing at all.
    it "covers every construct the extractor defers" do
      outcome = round_trip(fixtures)
      kinds =
        outcome.placeholders.values.flatten.map { |token| Migrations::Placeholder.kind(token) }

      expect(kinds.uniq).to match_array(%w[emoji hashtag link mention quote upload])
    end

    # The origin rewrite is the one difference the contract allows, so it has to
    # actually happen — and only on the source site's own links.
    it "moves a source-site link onto the destination base URL" do
      name = "links"
      outcome = round_trip(fixtures.slice(name))

      expect(outcome.resolved[name]).not_to eq(fixtures[name])
      expect(outcome.resolved[name]).to include("#{ExtractionRoundTrip::BASE_URL}/faq")
      expect(outcome.resolved[name]).to include("[elsewhere](https://blog.example.net/posts/1)")
    end
  end

  describe "placeholder bookkeeping" do
    it "leaves no token without an embed row" do
      outcome = round_trip(fixtures)

      expect(outcome.orphans).to be_empty
    end

    it "puts every minted token into the extracted body exactly once" do
      outcome = round_trip(fixtures)

      miscounted =
        outcome.placeholders.flat_map do |name, tokens|
          tokens
            .reject { |token| outcome.extracted[name].scan(token).size == 1 }
            .map { |token| "#{name}: #{token.inspect}" }
        end

      expect(miscounted).to be_empty
    end

    it "leaves no token in the resolved body" do
      outcome = round_trip(fixtures)

      leftovers = outcome.resolved.select { |_name, body| Migrations::Placeholder.include?(body) }

      expect(leftovers.keys).to be_empty
    end
  end

  describe "batched and per-body scanning" do
    it "extracts and resolves a batch exactly as it does one body at a time" do
      batched = round_trip(fixtures, batched: true)
      per_body = round_trip(fixtures, batched: false)

      expect(batched.extracted).to eq(per_body.extracted)
      expect(batched.resolved).to eq(per_body.resolved)
      expect(batched.refusals).to eq(per_body.refusals)
    end

    # A body that had to be scanned again inside `extract_prepared` means the
    # batch call dropped it, which the identical results above would hide. The
    # engine-bound count guards the other way: without it a fixture set that
    # never reaches the engine would satisfy this trivially.
    it "scans no body again outside the batch" do
      outcome = round_trip(fixtures, batched: true)

      expect(outcome.engine_bound).to be > 1
      expect(outcome.live_scans).to eq(0)
    end
  end

  describe "a body the extractor refuses" do
    let(:name) { ExtractionRoundTrip::REFUSED_FIXTURE }
    let(:body) { ExtractionRoundTrip.fixtures.fetch(name) }

    # A refusal keeps the body out of the contract rather than breaking it: the
    # bytes are handed on untouched, and the cause is reported so a conversion
    # can list what still needs resolving.
    it "hands the body on verbatim and reports the cause" do
      outcome = round_trip({ name => body })

      expect(outcome.extracted[name]).to eq(body)
      expect(outcome.resolved[name]).to eq(body)
      expect(outcome.placeholders[name]).to be_empty
      expect(outcome.refusals).to eq(invalid_internal_route: 1)
    end
  end
end
