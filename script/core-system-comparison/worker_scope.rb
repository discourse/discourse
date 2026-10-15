# frozen_string_literal: true
require "json"
require "fileutils"
require "pathname"

RSpec.configure do |config|
  config.before(:suite) do
    files =
      RSpec
        .configuration
        .files_to_run
        .map do |path|
          Pathname.new(File.expand_path(path)).relative_path_from(Pathname.new(Dir.pwd)).to_s
        end
        .sort
    record = {
      worker: ENV.fetch("TEST_ENV_NUMBER", "multisite"),
      files: files,
      seed: RSpec.configuration.seed,
      adapter_loaded: !!defined?(Capybara::Playwright),
      adapter_page_hook:
        Playwright::Page.ancestors.any? do |ancestor|
          ancestor.name.to_s.start_with?("Capybara::Playwright")
        end,
      ruby: RUBY_VERSION,
      playwright: Playwright::VERSION,
      capybara: Capybara::VERSION,
    }
    FileUtils.mkdir_p("tmp/direct-worker-scope")
    File.write("tmp/direct-worker-scope/worker-#{record[:worker]}.json", JSON.generate(record))
    puts "DIRECT_WORKER_SCOPE=" + JSON.generate(record)
  end
end
