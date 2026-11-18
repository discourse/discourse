# frozen_string_literal: true

RSpec.describe "Structured request logging", if: DiscourseLograge.enabled? do
  it "truncates the request parameters in the emitted JSON record" do
    GlobalSetting.stubs(:log_line_max_chars).returns(12)
    output = StringIO.new
    Lograge.stubs(:logger).returns(DiscourseLogstashLogger.logger(logdev: output, type: :rails))

    get "/about.json", params: { q: "structured logging" }

    expect(response.status).to eq(200)
    expect(JSON.parse(output.string)).to include(
      "path" => "/about.json",
      "params" => "q=structured...(truncated)",
    )
  end
end
