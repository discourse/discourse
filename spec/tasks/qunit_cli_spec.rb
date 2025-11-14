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
    )
  end

  it "works" do
    result = run
    expect(result.status).to eq(0)
    expect(result.out).to include("[dry-run]")
    expect(result.args).to match(
      ["pnpm", "ember", "exam", "--query", a_string_matching(/\Aseed=\d+\z/), "--path", "dist"],
    )
    expect(result.env.keys).to contain_exactly("UNICORN_PORT", "TESTEM_DEFAULT_BROWSER")
  end
end
