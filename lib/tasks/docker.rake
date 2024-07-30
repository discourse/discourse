# frozen_string_literal: true

# The Rake tasks in this file are designed to be used inside the `discourse/discourse_test:release` image.
# Running it anywhere else is not supported.

def run_or_fail(command)
  log(command)
  pid = Process.spawn(command)
  Process.wait(pid)
  $?.exitstatus == 0
end

def log(message)
  puts "[#{Time.now.strftime("%Y-%m-%d %H:%M:%S")}] #{message}"
end

def setup_postgres(skip_init:)
  unless skip_init
    log "Initializing postgres"
    system("script/start_test_db.rb --skip-run", exception: true)
  end

  log "Starting postgres"
  Process.spawn("script/start_test_db.rb --skip-setup --exec")
end

def setup_redis
  log "Starting background redis"
  data_directory = "#{Rails.root}/tmp/test_data/redis"
  `rm -rf #{data_directory} && mkdir -p #{data_directory}`
  Process.spawn("redis-server --dir #{data_directory}")
end

def setup_test_env(
  setup_multisite: false,
  create_db: true,
  create_parallel_dbs: false,
  install_all_official: false,
  update_all_plugins: false,
  plugins_to_remove: "",
  load_plugins: false
)
  ENV["RAILS_ENV"] = "test"
  # this shaves all the creation of the multisite db off
  # for js tests
  ENV["SKIP_MULTISITE"] = "1" unless setup_multisite

  success = true
  success &&= run_or_fail("bundle exec rake db:create") if create_db
  success &&= run_or_fail("bundle exec rake parallel:create") if create_parallel_dbs
  success &&= run_or_fail("bundle exec rake plugin:install_all_official") if install_all_official
  success &&= run_or_fail("bundle exec rake plugin:update_all") if update_all_plugins

  if !plugins_to_remove.blank?
    plugins_to_remove
      .split(",")
      .map(&:strip)
      .each do |plugin|
        puts "[SKIP_INSTALL_PLUGINS] Removing #{plugin}"
        `rm -fr plugins/#{plugin}`
      end
  end

  success &&= migrate_databases(parallel: create_parallel_dbs, load_plugins: load_plugins)
  success
end

def migrate_databases(parallel: false, load_plugins: false)
  migrate_env = load_plugins ? "LOAD_PLUGINS=1" : "LOAD_PLUGINS=0"

  success = true
  success &&=
    run_or_fail("#{migrate_env} script/silence_successful_output bundle exec rake db:migrate")
  success &&=
    run_or_fail(
      "#{migrate_env} script/silence_successful_output bundle exec rake parallel:migrate",
    ) if parallel
  success
end

def number_of_processors
  Etc.nprocessors
end

def system_tests_parallel_tests_processors_env
  "PARALLEL_TEST_PROCESSORS=#{number_of_processors / 2}"
end

# Environment Variables (specific to this rake task)
# => INSTALL_OFFICIAL_PLUGINS  set to 1 to install all official plugins
# => UPDATE_ALL_PLUGINS        set to 1 to update all plugins
# => LOAD_PLUGINS              set to 1 to load plugins
# => CREATE_PARALLEL_DATABASES set to 1 to setup parallel test databases
desc "Setups up the test environment"
task "docker:test:setup" do
  setup_redis
  setup_postgres(skip_init: false)

  setup_test_env(
    setup_multisite: true,
    create_db: true,
    create_parallel_dbs: !!ENV["CREATE_PARALLEL_DATABASES"],
    load_plugins: !!ENV["LOAD_PLUGINS"],
    install_all_official: !!ENV["INSTALL_OFFICIAL_PLUGINS"],
    update_all_plugins: !!ENV["UPDATE_ALL_PLUGINS"],
  )
end

# Environment Variables (specific to this rake task)
# => SKIP_LINT                 set to 1 to skip linting (eslint and rubocop)
# => SKIP_TESTS                set to 1 to skip all tests
# => SKIP_CORE                 set to 1 to skip core tests (rspec and qunit)
# => SKIP_PLUGINS              set to 1 to skip plugin tests (rspec and qunit)
# => SKIP_INSTALL_PLUGINS      comma separated list of plugins you want to skip installing
# => INSTALL_OFFICIAL_PLUGINS  set to 1 to install all core plugins before running tests
# => RUN_SYSTEM_TESTS          set to 1 to run the system tests as well
# => RUBY_ONLY                 set to 1 to skip all qunit tests
# => JS_ONLY                   set to 1 to skip all rspec tests
# => SINGLE_PLUGIN             set to plugin name to only run plugin-specific rspec tests (you'll probably want to SKIP_CORE as well)
# => BISECT                    set to 1 to run rspec --bisect (applies to core rspec tests only)
# => RSPEC_SEED                set to seed to use for rspec tests (applies to core rspec tests only)
# => PAUSE_ON_TERMINATE        set to 1 to pause prior to terminating redis and pg
# => JS_TIMEOUT                set timeout for qunit tests in ms
# => WARMUP_TMP_FOLDER runs a single spec to warmup the tmp folder and obtain accurate results when profiling specs.
#
# Other useful environment variables (not specific to this rake task)
# => COMMIT_HASH    used by the discourse_test docker image to load a specific commit of discourse
#                   this can also be set to a branch, e.g. "origin/tests-passed"
#
# Example usage:
#   Run all core and plugin tests:
#       docker run discourse/discourse_test:release
#   Run only rspec tests:
#       docker run -e RUBY_ONLY=1 discourse/discourse_test:release
#   Run all plugin tests (with a plugin mounted from host filesystem):
#       docker run -e SKIP_CORE=1 -v $(pwd)/my-awesome-plugin:/var/www/discourse/plugins/my-awesome-plugin discourse/discourse_test:release
#   Run tests for a specific plugin (with a plugin mounted from host filesystem):
#       docker run -e SKIP_CORE=1 SINGLE_PLUGIN='my-awesome-plugin' -v $(pwd)/my-awesome-plugin:/var/www/discourse/plugins/my-awesome-plugin discourse/discourse_test:release
desc "Run all tests (JS and code in a standalone environment)"
task "docker:test" do
  def run_or_fail_prettier(*patterns)
    if patterns.any? { |p| Dir[p].any? }
      patterns = patterns.map { |p| "'#{p}'" }.join(" ")
      run_or_fail("yarn pprettier --list-different #{patterns}")
    else
      puts "Skipping prettier. Pattern not found."
      true
    end
  end

  begin
    @good = true
    @good &&= run_or_fail("yarn install")

    unless ENV["SKIP_LINT"]
      puts "Running linters/prettyfiers"
      puts "eslint #{`yarn eslint -v`}"
      puts "prettier #{`yarn prettier -v`}"

      if ENV["SINGLE_PLUGIN"]
        @good &&= run_or_fail("bundle exec rubocop --parallel plugins/#{ENV["SINGLE_PLUGIN"]}")
        @good &&=
          run_or_fail(
            "bundle exec ruby script/i18n_lint.rb plugins/#{ENV["SINGLE_PLUGIN"]}/config/locales/{client,server}.en.yml",
          )
        @good &&=
          run_or_fail(
            "yarn eslint --ext .js,.js.es6 --no-error-on-unmatched-pattern plugins/#{ENV["SINGLE_PLUGIN"]}",
          )

        puts "Listing prettier offenses in #{ENV["SINGLE_PLUGIN"]}:"
        @good &&=
          run_or_fail_prettier(
            "plugins/#{ENV["SINGLE_PLUGIN"]}/**/*.scss",
            "plugins/#{ENV["SINGLE_PLUGIN"]}/**/*.{js,es6}",
          )
      else
        @good &&= run_or_fail("bundle exec rake plugin:update_all") unless ENV["SKIP_PLUGINS"]
        @good &&= run_or_fail("bundle exec rubocop --parallel") unless ENV["SKIP_CORE"]
        @good &&= run_or_fail("yarn eslint app/assets/javascripts") unless ENV["SKIP_CORE"]
        @good &&=
          run_or_fail(
            "yarn eslint --ext .js,.js.es6 --no-error-on-unmatched-pattern plugins",
          ) unless ENV["SKIP_PLUGINS"]

        @good &&=
          run_or_fail(
            'bundle exec ruby script/i18n_lint.rb "config/locales/{client,server}.en.yml"',
          ) unless ENV["SKIP_CORE"]
        @good &&=
          run_or_fail(
            'bundle exec ruby script/i18n_lint.rb "plugins/**/locales/{client,server}.en.yml"',
          ) unless ENV["SKIP_PLUGINS"]

        unless ENV["SKIP_CORE"]
          puts "Listing prettier offenses in core:"
          @good &&=
            run_or_fail(
              'yarn pprettier --list-different "app/assets/stylesheets/**/*.scss" "app/assets/javascripts/**/*.js"',
            )
        end

        unless ENV["SKIP_PLUGINS"]
          puts "Listing prettier offenses in plugins:"
          @good &&=
            run_or_fail(
              'yarn pprettier --list-different "plugins/**/assets/stylesheets/**/*.scss" "plugins/**/assets/javascripts/**/*.{js,es6}"',
            )
        end
      end
    end

    unless ENV["SKIP_TESTS"]
      @redis_pid = setup_redis
      @pg_pid = setup_postgres(skip_init: ENV["SKIP_DB_CREATE"].present?)

      @good &&=
        setup_test_env(
          setup_multisite: !ENV["JS_ONLY"],
          create_db: !ENV["SKIP_DB_CREATE"],
          create_parallel_dbs: !!ENV["USE_TURBO"],
          install_all_official: !!ENV["INSTALL_OFFICIAL_PLUGINS"],
          update_all_plugins: !!ENV["UPDATE_ALL_PLUGINS"],
          plugins_to_remove: ENV["SKIP_INSTALL_PLUGINS"] || "",
          load_plugins: !ENV["SKIP_PLUGINS"],
        )

      unless ENV["JS_ONLY"]
        @good &&= run_or_fail("bin/ember-cli --build") if ENV["RUN_SYSTEM_TESTS"]

        if ENV["WARMUP_TMP_FOLDER"]
          run_or_fail("bundle exec rspec ./spec/requests/groups_controller_spec.rb")
        end

        unless ENV["SKIP_CORE"]
          params = []

          unless ENV["USE_TURBO"]
            params << "--profile"
            params << "--fail-fast"
            params << "--bisect" if ENV["BISECT"]
            params << "--seed #{ENV["RSPEC_SEED"]}" if ENV["RSPEC_SEED"]
          end

          if ENV["USE_TURBO"]
            @good &&=
              run_or_fail("bundle exec ./bin/turbo_rspec --verbose #{params.join(" ")}".strip)
          else
            @good &&= run_or_fail("bundle exec rspec #{params.join(" ")}".strip)
          end

          if ENV["RUN_SYSTEM_TESTS"]
            @good &&=
              if ENV["USE_TURBO"]
                run_or_fail(
                  "#{system_tests_parallel_tests_processors_env} timeout --verbose 1800 bundle exec ./bin/turbo_rspec spec/system",
                )
              else
                run_or_fail("timeout --verbose 1800 bundle exec rspec spec/system")
              end
          end
        end

        unless ENV["SKIP_PLUGINS"]
          if ENV["SINGLE_PLUGIN"]
            @good &&= run_or_fail("bundle exec rake plugin:spec['#{ENV["SINGLE_PLUGIN"]}']")

            if ENV["RUN_SYSTEM_TESTS"]
              @good &&=
                run_or_fail(
                  "LOAD_PLUGINS=1 timeout --verbose 1600 bundle exec rspec plugins/#{ENV["SINGLE_PLUGIN"]}/spec/system".strip,
                )
            end
          else
            fail_fast = "RSPEC_FAILFAST=1" unless ENV["SKIP_FAILFAST"]
            task = ENV["USE_TURBO"] ? "plugin:turbo_spec" : "plugin:spec"
            @good &&= run_or_fail("#{fail_fast} bundle exec rake #{task}")

            if ENV["RUN_SYSTEM_TESTS"]
              @good &&=
                if ENV["USE_TURBO"]
                  run_or_fail(
                    "LOAD_PLUGINS=1 #{system_tests_parallel_tests_processors_env} timeout --verbose 1600 bundle exec ./bin/turbo_rspec plugins/*/spec/system",
                  )
                else
                  run_or_fail(
                    "LOAD_PLUGINS=1 timeout --verbose 1600 bundle exec rspec plugins/*/spec/system",
                  )
                end
            end
          end
        end
      end

      unless ENV["RUBY_ONLY"]
        js_timeout = ENV["JS_TIMEOUT"].presence || 900_000 # 15 minutes

        unless ENV["SKIP_CORE"]
          @good &&=
            run_or_fail(
              "cd app/assets/javascripts/discourse && CI=1 yarn ember exam --load-balance --parallel=#{number_of_processors / 2} --random",
            )
        end

        unless ENV["SKIP_PLUGINS"]
          if ENV["SINGLE_PLUGIN"]
            @good &&=
              run_or_fail(
                "CI=1 bundle exec rake plugin:qunit['#{ENV["SINGLE_PLUGIN"]}','#{js_timeout}']",
              )
          else
            @good &&=
              run_or_fail(
                "QUNIT_PARALLEL=#{number_of_processors / 2}  CI=1 bundle exec rake plugin:qunit['*','#{js_timeout}']",
              )
          end
        end
      end
    end
  ensure
    puts "Terminating"

    if ENV["PAUSE_ON_TERMINATE"]
      puts "Pausing prior to termination"
      sleep
    end

    Process.kill("TERM", @redis_pid) if @redis_pid
    Process.kill("TERM", @pg_pid) if @pg_pid
    Process.wait @redis_pid if @redis_pid
    Process.wait @pg_pid if @pg_pid
  end

  exit 1 unless @good
end
