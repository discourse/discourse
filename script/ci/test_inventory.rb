# frozen_string_literal: true
require "json"
require "open3"
require "digest"

module TestInventory
  def self.test_file?(path)
    !path.start_with?("frontend/discourse/tests/helpers/") &&
      path.match?(
        %r{\A(?:spec/.*_spec\.rb|plugins/[^/]+/spec/.*_spec\.rb|(?:tmp/)?themes/[^/]+/spec/system/.*_spec\.rb|migrations/[^/]+/spec/.*_spec\.rb|frontend/discourse/tests/.*-test\.(?:js|gjs|ts|gts)|plugins/[^/]+/test/javascripts/.*-test\.(?:js|gjs|ts|gts)|(?:tmp/)?themes/[^/]+/test/.*-test\.(?:js|gjs|ts|gts)|frontend/asset-processor/.*\.(?:test|spec)\.(?:js|mjs|cjs|ts|mts|cts|jsx|tsx))\z},
      )
  end

  def self.jobs(bundled:, files: nil)
    paths =
      lambda do |pattern|
        if files
          files.select do |path|
            File.fnmatch?(pattern, path, File::FNM_PATHNAME | File::FNM_EXTGLOB)
          end
        else
          Dir[pattern]
        end
      end
    plugin_specs = paths.call("plugins/*/spec/**/*_spec.rb").sort
    systems = plugin_specs.select { |path| path.include?("/spec/system/") }
    jobs = {
      "core-backend" =>
        rspec(
          files: paths.call("spec/**/*_spec.rb").reject { |path| path.start_with?("spec/system/") },
          plugins: false,
        ),
      "plugins-backend" => rspec(files: plugin_specs - systems, plugins: true),
      "core-system" => rspec(files: paths.call("spec/system/**/*_spec.rb"), plugins: false),
      "core-plugins-system" =>
        rspec(
          files:
            systems.select do |path|
              bundled.any? { |plugin| path.start_with?("#{plugin}/") } &&
                !path.start_with?("plugins/chat/")
            end,
          plugins: true,
        ),
      "chat-system" =>
        rspec(files: systems.select { |path| path.start_with?("plugins/chat/") }, plugins: true),
      "official-plugins-system" =>
        rspec(
          files: systems.reject { |path| bundled.any? { |plugin| path.start_with?("#{plugin}/") } },
          plugins: true,
        ),
      "themes-system" =>
        rspec(files: paths.call("{tmp/themes,themes}/*/spec/system/**/*_spec.rb"), plugins: false),
      "core-frontend" =>
        qunit(
          files:
            paths
              .call("frontend/discourse/tests/**/*-test.{js,gjs,ts,gts}")
              .select { |path| test_file?(path) },
          plugins: false,
        ),
      "plugins-frontend" =>
        qunit(
          files: paths.call("plugins/*/test/javascripts/**/*-test.{js,gjs,ts,gts}"),
          plugins: true,
        ),
      "themes-frontend" => {
        "inventory" => paths.call("{tmp/themes,themes}/*/test/**/*-test.{js,gjs,ts,gts}").sort,
        "runner" => "qunit",
        "command" => %w[ruby script/ci/theme_test_selection.rb],
        "env" => {
          "LOAD_PLUGINS" => "1",
          "DISCOURSE_DEV_DB" => "discourse_test",
        },
      },
      "asset-processor" => {
        "inventory" =>
          paths
            .call("frontend/asset-processor/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}")
            .reject { |path| path.include?("/node_modules/") }
            .sort,
        "runner" => "vitest",
        "command" => %w[pnpm exec vitest run],
        "cwd" => "frontend/asset-processor",
      },
    }
    %w[core tooling converters importer].each do |gem|
      [false, true].each do |rails|
        jobs["migrations-#{gem}-#{rails ? "rails" : "plain"}"] = {
          "inventory" => paths.call("migrations/#{gem}/spec/**/*_spec.rb").sort,
          "runner" => "rspec",
          "cwd" => "migrations/#{gem}",
          "order" => rails ? "random" : "defined",
          "command" => ["../bin/rspec", "--tag", rails ? "rails" : "~rails"],
          "env" => {
            "MIGRATIONS_RAILS" => rails ? "1" : nil,
            "LOAD_PLUGINS" => "1",
          },
        }
      end
    end
    jobs
  end

  def self.catalog(revision:)
    paths, status = Open3.capture2("git", "ls-tree", "--name-only", "-d", "HEAD", "plugins/")
    raise "Cannot discover bundled plugins" unless status.success?
    bundled = paths.lines.map(&:strip)
    jobs = jobs(bundled:)
    required_inputs = %w[
      Gemfile
      Gemfile.lock
      pnpm-lock.yaml
      .github/workflows/tests.yml
      .github/workflows/migration-tests.yml
    ]
    runtime_inputs =
      (
        %w[
          .github/workflows/test-plan.yml
          .github/workflows/test-mapping.yml
          bin/qunit
          bin/turbo_rspec
          lib/turbo_tests/runner.rb
          frontend/discourse/testem.js
          frontend/discourse/tests/test-boot-ember-cli.js
          frontend/discourse/lib/wrap-test-modules-plugin.mjs
          frontend/asset-processor/asset-processor-rollup.js
          frontend/asset-processor/rollup-plugins/discourse-test-modules.js
        ] + Dir["script/ci/*.rb"]
      ).select { |path| File.file?(path) }
    fingerprints =
      (required_inputs + runtime_inputs).uniq.sort.to_h do |path|
        [path, Digest::SHA256.file(path).hexdigest]
      end
    external =
      Dir["plugins/*/.git", "tmp/themes/*/.git"].sort.to_h do |path|
        directory = File.dirname(path)
        external_revision, status = Open3.capture2("git", "-C", directory, "rev-parse", "HEAD")
        raise "Cannot identify external checkout: #{directory}" unless status.success?
        [directory, external_revision.strip]
      end
    jobs.each do |name, job|
      if name.end_with?("-system")
        job.fetch("env").merge!(
          "CHECKOUT_TIMEOUT" => "10",
          "RAILS_ENABLE_TEST_LOG" => "1",
          "RAILS_TEST_LOG_LEVEL" => "error",
        )
      end
      relevant =
        external.select do |path, _|
          (
            path.start_with?("plugins/") &&
              %w[plugins-backend plugins-frontend official-plugins-system].include?(name)
          ) || (path.start_with?("tmp/themes/") && name.start_with?("themes-"))
        end
      configuration = job.reject { |key, _| key == "inventory" }
      job["environment"] = Digest::SHA256.hexdigest(
        JSON.generate([name, configuration, fingerprints, RUBY_VERSION, relevant]),
      )
    end
    {
      "revision" => revision,
      "seed" => revision[0, 8].to_i(16),
      "repository_catalog" => true,
      "checkouts" => external,
      "jobs" => jobs,
    }
  end

  def self.rspec(files:, plugins:)
    {
      "inventory" => files.sort,
      "runner" => "rspec",
      "command" => %w[bin/turbo_rspec --use-runtime-info --format documentation],
      "env" => {
        "LOAD_PLUGINS" => plugins ? "1" : "0",
      },
    }
  end
  private_class_method :rspec

  def self.qunit(files:, plugins:)
    {
      "inventory" => files.sort,
      "runner" => "qunit",
      "command" => %w[bin/qunit --standalone --exact-files],
      "env" => {
        "LOAD_PLUGINS" => plugins ? "1" : "0",
      },
    }
  end
  private_class_method :qunit
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected OUTPUT" unless ARGV.length == 1
    File.write(
      ARGV.first,
      JSON.pretty_generate(TestInventory.catalog(revision: ENV.fetch("GITHUB_SHA"))),
    )
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
