# frozen_string_literal: true

RSpec.describe "compatibility:validate" do
  def invoke(content)
    file = Tempfile.new("discourse-compat-validate")
    file.write content
    file.close
    error = nil
    stdout =
      capture_stdout do
        invoke_rake_task("compatibility:validate", file.path)
      rescue => e
        error = e
      end
    [error, stdout]
  ensure
    file.unlink
  end

  it "passes for a valid .discourse-compatibility file" do
    error, stdout = invoke <<~CONTENT
      2.5.0.beta6: c4a6c17
      2.5.0.beta4: d1d2d3f
    CONTENT
    expect(error).to eq(nil)
    expect(stdout).to include("Compatibility file is valid")
  end

  it "passes for empty file" do
    error, stdout = invoke ""
    expect(error).to eq(nil)
    expect(stdout).to include("Compatibility file is valid")
  end

  it "fails for invalid YAML" do
    error, stdout = invoke <<~CONTENT
      2.5.0.beta6 c4a6c17
    CONTENT
    expect(error).to be_a(Discourse::InvalidVersionListError)
    expect(stdout).to include("Invalid version list")
  end

  it "fails for invalid version specifier" do
    error, stdout = invoke <<~CONTENT
      > 2.5.0.beta6: c4a6c17
    CONTENT
    expect(error).to be_a(Discourse::InvalidVersionListError)
    expect(stdout).to include("Invalid version list")
  end

  it "fails when matching current core version" do
    error, stdout = invoke <<~CONTENT
      #{Discourse::VERSION::STRING}: c4a6c17
    CONTENT
    expect(error).to be_a(CoreTooRecentError)
    expect(stdout).to include(
      "Compatibility file has an entry which matches the current version of Discourse core",
    )
  end
end
