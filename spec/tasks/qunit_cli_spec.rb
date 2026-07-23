# frozen_string_literal: true

describe "bin/qunit" do
  def run(*args, env: {})
    out, err, status = Open3.capture3(env, "bin/qunit", "--dry-run", *args, chdir: Rails.root.to_s)

    parsed_args, parsed_env =
      if parsed_result = out.match(/Executing: (?<args>\[.+?\])\nwith env: (?<env>\{.+?\})/m)
        [JSON.parse(parsed_result[:args]), JSON.parse(parsed_result[:env])]
      end

    OpenStruct.new(
      out: out,
      err: err,
      status: status.exitstatus,
      args: parsed_args,
      env: parsed_env,
      launched_server: out.include?("[dry-run] skipping server startup"),
    )
  end

  let(:core_test_file) do
    Dir.glob("#{Rails.root.join("frontend/discourse/tests/integration/**/*-test.js")}").first
  end

  let(:chat_test_file) { Dir.glob("#{Rails.root.join("plugins/chat/test/**/*-test.js")}").first }

  let(:default_watchdog_env) do
    {
      "QUNIT_BROWSER_WATCHDOG" => "1",
      "QUNIT_BROWSER_START_TIMEOUT" => "45",
      "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "30",
    }
  end

  it "runs all core tests by default" do
    result = run
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=core&testem=1",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      default_watchdog_env.merge(
        "UNICORN_PORT" => a_truthy_value,
        "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
        "LOAD_PLUGINS" => "0",
      ),
    )
  end

  it "allows running specific file" do
    result = run(core_test_file)
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=core&testem=1",
        "--file-path",
        core_test_file.sub("#{Rails.root.join("frontend/discourse/tests/")}", ""),
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      default_watchdog_env.merge(
        "UNICORN_PORT" => a_truthy_value,
        "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
        "LOAD_PLUGINS" => "0",
      ),
    )
  end

  it "allows running all plugin tests" do
    result = run("--target", "plugins")
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "testem=1",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      default_watchdog_env.merge(
        "UNICORN_PORT" => a_truthy_value,
        "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
        "LOAD_PLUGINS" => "1",
        "PLUGIN_TARGETS" => a_string_matching(/,/),
      ),
    )
  end

  it "allows running tests for multiple plugins" do
    result = run("--target", "chat,discourse-local-dates")
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "testem=1",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      default_watchdog_env.merge(
        "UNICORN_PORT" => a_truthy_value,
        "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
        "LOAD_PLUGINS" => "1",
        "PLUGIN_TARGETS" => "chat,discourse-local-dates",
      ),
    )
  end

  it "allows running specific plugin test file" do
    result = run(chat_test_file)
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=chat&testem=1",
        "--file-path",
        chat_test_file.sub(
          "#{Rails.root.join("plugins/chat/test/javascripts/")}",
          "discourse/plugins/chat/",
        ),
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      default_watchdog_env.merge(
        "UNICORN_PORT" => a_truthy_value,
        "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
        "LOAD_PLUGINS" => "1",
      ),
    )
  end

  it "prevents running files from multiple targets" do
    result = run(core_test_file, chat_test_file)
    expect(result.status).to eq(1)
    expect(result.out).to include(
      "Error: Cannot mix multiple plugin/core targets when running specific files",
    )
  end

  it "launches server when using --standalone" do
    result = run("--standalone")
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(true)
  end

  it "enables the browser watchdog with default settings" do
    result = run

    expect(result.env).to include(
      "QUNIT_BROWSER_WATCHDOG" => "1",
      "QUNIT_BROWSER_START_TIMEOUT" => "45",
      "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "30",
    )
  end

  it "allows browser watchdog settings to be configured through the environment" do
    result =
      run(
        env: {
          "QUNIT_BROWSER_WATCHDOG" => "0",
          "QUNIT_BROWSER_START_TIMEOUT" => "60",
          "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "40",
        },
      )

    expect(result.env).to include(
      "QUNIT_BROWSER_WATCHDOG" => "0",
      "QUNIT_BROWSER_START_TIMEOUT" => "60",
      "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "40",
    )
  end

  it "gives browser watchdog CLI settings precedence over the environment" do
    result =
      run(
        "--browser-watchdog",
        "--browser-start-timeout",
        "70",
        "--browser-inactivity-timeout",
        "50",
        env: {
          "QUNIT_BROWSER_WATCHDOG" => "0",
          "QUNIT_BROWSER_START_TIMEOUT" => "60",
          "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "40",
        },
      )

    expect(result.env).to include(
      "QUNIT_BROWSER_WATCHDOG" => "1",
      "QUNIT_BROWSER_START_TIMEOUT" => "70",
      "QUNIT_BROWSER_INACTIVITY_TIMEOUT" => "50",
    )
  end

  it "rejects non-positive browser watchdog settings" do
    result = run("--browser-inactivity-timeout", "0")

    expect(result.status).to eq(1)
    expect(result.err).to include("--browser-inactivity-timeout must be greater than 0")
  end
end
