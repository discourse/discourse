# frozen_string_literal: true

require "json"
require_relative "assertions"

module McpContentRestrictionsUnit2
  ENRICHMENT_INVENTORY =
    JSON.parse(File.read(File.join(__dir__, "enrichment_inventory.json"))).freeze
end

describe McpContentRestrictionsUnit2 do
  include McpContentRestrictionsUnit2::Assertions

  let(:inventory) { McpContentRestrictionsUnit2::ENRICHMENT_INVENTORY }

  it "[cr-u2] accounts for every write primitive in the live core and plugin registry" do
    writes =
      DiscourseMcp.registry.all.select do |primitive|
        primitive.kind == :tool && primitive.annotations["readOnlyHint"] != true
      end
    classified = inventory.fetch("operations").map { |operation| operation.fetch("tool") }.uniq
    expect(writes.map(&:identifier) - classified).to eq([])
    expect(writes).to be_present
    if ENV["LOAD_PLUGINS"] == "1"
      expect(classified - writes.map(&:identifier)).to eq([])
      expect(writes.map(&:provider)).to include(
        "core",
        "chat",
        "discourse-reactions",
        "discourse-solved",
        "discourse-topic-voting",
      )
    end
    writes.each do |primitive|
      entries =
        inventory
          .fetch("operations")
          .select { |operation| operation.fetch("tool") == primitive.identifier }
      entries.each do |operation|
        expect(operation.fetch("trigger")).to be_present
        expect(operation.fetch("raw")).to be_present
        expect(operation.fetch("evidence")).to be_present
        expect_no_cooking(operation) if operation.fetch("paths").empty?
      end
    end
  end

  it "[cr-u2] keeps every path reference and exact file:line evidence reviewable" do
    paths = inventory.fetch("paths")
    rows = inventory.fetch("operations") + paths.values + inventory.fetch("excluded_candidates")
    aggregate_failures do
      rows.each do |row|
        (row["paths"] || row["downstream"] || []).each do |reference|
          expect(paths).to have_key(reference)
        end
        row
          .fetch("evidence")
          .each do |evidence|
            path = Rails.root.join(evidence.fetch("file"))
            expect(path).to be_file
            source_line = path.readlines.fetch(evidence.fetch("line") - 1).strip
            expect(source_line).to eq(evidence.fetch("source")),
            "Re-review stale evidence: #{path}:#{evidence.fetch("line")}"
          end
      end
    end
  end
end
