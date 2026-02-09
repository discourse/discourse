# frozen_string_literal: true

describe "bin/qunit" do
  def run(*args)
    out, err, status = Open3.capture3("bin/qunit", "--dry-run", *args, chdir: Rails.root.to_s)

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
      launched_unicorn: out.include?("[dry-run] skipping unicorn startup"),
    )
  end

  let(:core_test_file) do
    Dir.glob("#{Rails.root}/frontend/discourse/tests/integration/**/*-test.js").first
  end

  let(:chat_test_file) { Dir.glob("#{Rails.root}/plugins/chat/test/**/*-test.js").first }

  it "runs all core tests by default" do
    result = run
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=core",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      "UNICORN_PORT" => a_truthy_value,
      "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
      "LOAD_PLUGINS" => "0",
    )
  end

  it "allows running specific file" do
    result = run(core_test_file)
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=core",
        "--file-path",
        core_test_file.sub("#{Rails.root}/frontend/discourse/", ""),
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      "UNICORN_PORT" => a_truthy_value,
      "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
      "LOAD_PLUGINS" => "0",
    )
  end

  it "allows running all plugin tests" do
    result = run("--target", "plugins")
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      "UNICORN_PORT" => a_truthy_value,
      "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
      "LOAD_PLUGINS" => "1",
      "PLUGIN_TARGETS" => a_string_matching(/,/),
    )
  end

  it "allows running tests for multiple plugins" do
    result = run("--target", "chat,discourse-local-dates")
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      "UNICORN_PORT" => a_truthy_value,
      "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
      "LOAD_PLUGINS" => "1",
      "PLUGIN_TARGETS" => "chat,discourse-local-dates",
    )
  end

  it "allows running specific plugin test file" do
    result = run(chat_test_file)
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(false)

    expect(result.args).to match(
      [
        "pnpm",
        "ember",
        "exam",
        "--query",
        "target=chat",
        "--file-path",
        chat_test_file.sub(
          "#{Rails.root}/plugins/chat/test/javascripts/",
          "discourse/plugins/chat/",
        ),
        "--random",
        a_string_matching(/\A[a-zA-Z0-9]{8}\z/),
        "--path",
        "dist",
      ],
    )
    expect(result.env).to match(
      "UNICORN_PORT" => a_truthy_value,
      "TESTEM_DEFAULT_BROWSER" => a_truthy_value,
      "LOAD_PLUGINS" => "1",
    )
  end

  it "prevents running files from multiple targets" do
    result = run(core_test_file, chat_test_file)
    expect(result.status).to eq(1)
    expect(result.out).to include(
      "Error: Cannot mix multiple plugin/core targets when running specific files",
    )
  end

  it "launches unicorn when using --standalone" do
    result = run("--standalone")
    expect(result.status).to eq(0)
    expect(result.launched_unicorn).to eq(true)
  end
end
