# frozen_string_literal: true

load Rails.root.join("bin/qunit").to_s

describe "bin/qunit" do
  def run(*args, env: {})
    # Unset CI so the expectations hold both on a developer machine and on CI itself, where the
    # browser port is deliberately left to the OS.
    env = { "CI" => nil }.merge(env)
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
      "QUNIT_REMOTE_DEBUGGING_PORT" => a_string_matching(/\A\d+\z/),
    }
  end

  let(:derived_test_port) { ["--test-port", a_string_matching(/\A\d+\z/)] }

  it "runs all core tests by default" do
    result = run
    expect(result.status).to eq(0)
    expect(result.launched_server).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        *derived_test_port,
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
        *derived_test_port,
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
        *derived_test_port,
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
        *derived_test_port,
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
        *derived_test_port,
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

  describe "port derivation" do
    let(:runner) { QunitRunner.new(["--dry-run"]) }

    def offset_for(path)
      runner.instance_variable_set(:@rails_root, path)
      runner.instance_variable_set(:@port_offset, nil)
      runner.send(:port_offset)
    end

    it "keeps every derived port inside its own band" do
      band = QunitRunner::PORT_BAND_SIZE

      expect(offset_for("/some/checkout")).to be_between(0, band - 1)
    end

    it "derives a stable offset for the same checkout" do
      expect(offset_for("/some/checkout")).to eq(offset_for("/some/checkout"))
    end

    it "derives different offsets for different checkouts" do
      offsets = %w[/a/main /a/worktrees/one /a/worktrees/two].map { |path| offset_for(path) }

      expect(offsets.uniq.size).to eq(3)
    end

    it "gives concurrent worktrees non-overlapping port bands" do
      expect(QunitRunner::RAILS_PORT_BASE + QunitRunner::PORT_BAND_SIZE).to be <
        QunitRunner::TESTEM_PORT_BASE
      expect(QunitRunner::DEVTOOLS_PORT_BASE + QunitRunner::PORT_BAND_SIZE).to be <
        QunitRunner::RAILS_PORT_BASE
    end

    it "treats a port bound on either address family as unavailable" do
      server = TCPServer.open("127.0.0.1", 0)
      port = server.addr[1]

      begin
        expect(runner.send(:port_available?, port)).to eq(false)
      ensure
        server.close
      end
    end
  end

  describe "port selection" do
    def band_for(base)
      (base...(base + QunitRunner::PORT_BAND_SIZE))
    end

    def test_port(result)
      result.args[result.args.index("--test-port") + 1].to_i
    end

    it "runs the Rails server, testem and the browser on derived ports" do
      result = run("--standalone")

      expect(result.env["UNICORN_PORT"].to_i).to be_in(band_for(QunitRunner::RAILS_PORT_BASE))
      expect(result.env["QUNIT_REMOTE_DEBUGGING_PORT"].to_i).to be_in(
        band_for(QunitRunner::DEVTOOLS_PORT_BASE),
      )
      expect(test_port(result)).to be_in(band_for(QunitRunner::TESTEM_PORT_BASE))
    end

    it "picks the same ports on every run from the same checkout" do
      first = run("--standalone")
      second = run("--standalone")

      expect(first.env["UNICORN_PORT"]).to eq(second.env["UNICORN_PORT"])
      expect(first.env["QUNIT_REMOTE_DEBUGGING_PORT"]).to eq(
        second.env["QUNIT_REMOTE_DEBUGGING_PORT"],
      )
      expect(test_port(first)).to eq(test_port(second))
    end

    it "walks past a derived port that is already bound" do
      derived = run("--standalone").env["UNICORN_PORT"].to_i
      server = TCPServer.open("127.0.0.1", derived)

      begin
        expect(run("--standalone").env["UNICORN_PORT"].to_i).to be > derived
      ensure
        server.close
      end
    end

    it "lets TEST_SERVER_PORT override the derived Rails port" do
      free = TCPServer.open("127.0.0.1", 0)
      port = free.addr[1]
      free.close

      result = run("--standalone", env: { "TEST_SERVER_PORT" => port.to_s })
      expect(result.env["UNICORN_PORT"]).to eq(port.to_s)
    end

    it "lets the OS assign a browser port for every worker of a parallel run" do
      expect(run(env: { "QUNIT_PARALLEL" => "4" }).env["QUNIT_REMOTE_DEBUGGING_PORT"]).to eq("0")
    end

    it "leaves the testem and browser ports untouched when running on CI" do
      result = run(env: { "CI" => "1" })

      expect(result.args).not_to include("--test-port")
      expect(result.env).not_to include("QUNIT_REMOTE_DEBUGGING_PORT")
    end
  end
end
