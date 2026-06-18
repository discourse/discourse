# frozen_string_literal: true

# Contract guard for the thin-layers JSON:API endpoint — the analogue of the Graphiti
# SchemaDiff guard (api_schema_spec.rb). See docs/api-modernization-exploration.md, Part 9.
#
# Derives a contract descriptor from each controller's DSL config + jsonapi-serializer
# serializer (BaseController.jsonapi_contract) and diffs it against the committed baseline.
# Backwards-incompatible changes fail this spec with the exact violations; additive changes
# (a new attribute/filter/sort/relationship) pass silently.
#
# To intentionally break the contract (i.e. a new major API version), regenerate with:
#   FORCE_SCHEMA=true bin/rspec plugins/discourse-data-explorer/spec/integration/jsonapi_rb_contract_spec.rb
describe "Data Explorer thin-layers JSON:API contract" do
  let(:contract_path) do
    Rails.root.join("plugins/discourse-data-explorer/jsonapi_rb_contract.json")
  end

  let(:current) do
    { "queries" => DiscourseDataExplorer::JsonapiRb::QueriesController.jsonapi_contract }
  end

  def breaking_changes(old, new)
    breaks = []

    (old.keys - new.keys).each { |resource| breaks << "resource removed: #{resource}" }

    new.each do |resource, now|
      was = old[resource]
      next if was.nil? # new resource — additive

      if was["type"] != now["type"]
        breaks << "#{resource}: type changed #{was["type"]} → #{now["type"]}"
      end

      (was["attributes"] - now["attributes"]).each do |a|
        breaks << "#{resource}: attribute removed: #{a}"
      end
      (was["filters"] - now["filters"]).each { |f| breaks << "#{resource}: filter removed: #{f}" }
      (was["sorts"] - now["sorts"]).each { |s| breaks << "#{resource}: sort removed: #{s}" }
      (was["includes"] - now["includes"]).each do |i|
        breaks << "#{resource}: include removed: #{i}"
      end
      (was["stats"].keys - now["stats"].keys).each do |s|
        breaks << "#{resource}: stat removed: #{s}"
      end

      (was["relationships"].keys - now["relationships"].keys).each do |name|
        breaks << "#{resource}: relationship removed: #{name}"
      end
      was["relationships"].each do |name, kind|
        new_kind = now["relationships"][name]
        if new_kind && new_kind != kind
          breaks << "#{resource}: relationship #{name} changed #{kind} → #{new_kind}"
        end
      end

      if was["default_sort"] != now["default_sort"]
        breaks << "#{resource}: default_sort changed #{was["default_sort"]} → #{now["default_sort"]}"
      end
      if now["max_page_size"].to_i < was["max_page_size"].to_i
        breaks << "#{resource}: max_page_size lowered #{was["max_page_size"]} → #{now["max_page_size"]}"
      end
    end

    breaks
  end

  it "stays backwards-compatible with the committed contract" do
    if File.exist?(contract_path) && ENV["FORCE_SCHEMA"] != "true"
      committed = JSON.parse(File.read(contract_path))
      breaks = breaking_changes(committed, current)

      expect(breaks).to be_empty, <<~MSG
        Backwards-incompatible JSON:API contract changes detected:

        #{breaks.map { |b| "  - #{b}" }.join("\n")}

        If this is intentional, it is a new major API version: regenerate the contract
        with FORCE_SCHEMA=true and coordinate the version bump.
      MSG
    end

    File.write(contract_path, JSON.pretty_generate(current))
  end
end
