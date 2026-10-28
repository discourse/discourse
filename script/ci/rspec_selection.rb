# frozen_string_literal: true

require "json"
require "fileutils"

directory = "tmp/rspec-mapping"

case ARGV.fetch(0)
when "merge"
  workers = Dir["#{directory}/worker-*.json"].map { |file| JSON.parse(File.read(file)) }
  revision = ENV.fetch("GITHUB_SHA")
  unless workers.any? &&
           workers.all? { |worker| worker["complete"] && worker["revision"] == revision }
    abort "Incomplete RSpec mapping"
  end

  dependencies = Hash.new { |mapping, spec| mapping[spec] = [] }
  workers.each do |worker|
    worker.fetch("dependencies").each { |spec, sources| dependencies[spec] |= sources }
  end
  File.write(
    "#{directory}/mapping.json",
    JSON.generate(
      version: 1,
      revision: revision,
      dependencies: dependencies,
      shared_globs: workers.flat_map { |worker| worker.fetch("shared_globs") }.uniq,
    ),
  )
when "run"
  selection =
    begin
      JSON.parse(File.read("#{directory}/selection.json"))
    rescue Errno::ENOENT, JSON::ParserError
      { "mode" => "full" }
    end
  if selection["mode"] == "subset" && selection["revision"] == ENV.fetch("GITHUB_SHA")
    specs = selection.fetch("specs")
    available_specs =
      Dir.glob("spec/**/*_spec.rb").reject { |spec| spec.start_with?("spec/system/") }
    abort "Invalid RSpec selection" unless specs.is_a?(Array) && (specs - available_specs).empty?
    puts "Selected #{specs.size} core backend spec files"
    exit 0 if specs.empty?
  else
    specs = []
    puts "Running the full core backend suite"
  end
  exec "bin/turbo_rspec", "--use-runtime-info", "--format=progress", *specs
else
  abort "Expected merge or run"
end
