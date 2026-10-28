# frozen_string_literal: true

require "tmpdir"
require_relative "../../lib/rspec_test_selection"

RSpec.describe RspecTestSelection do
  before do
    @root = Dir.mktmpdir("rspec-selection")
    %w[lib spec/models config].each { |path| FileUtils.mkdir_p(File.join(@root, path)) }
    %w[shared consumer other].each do |name|
      File.write(File.join(@root, "lib/#{name}.rb"), "original #{name}")
      File.write(File.join(@root, "spec/models/#{name}_spec.rb"), "spec #{name}")
    end
    system("git", "-C", @root, "init", "--quiet", exception: true)
    system("git", "-C", @root, "config", "user.name", "RSpec", exception: true)
    system("git", "-C", @root, "config", "user.email", "rspec@example.com", exception: true)
    commit_fixture
    records = [
      {
        "specs" =>
          %w[shared consumer other].to_h do |name|
            spec = "spec/models/#{name}_spec.rb"
            inputs = [spec, "lib/#{name}.rb"]
            [spec, { "passed" => true, "inputs" => inputs }]
          end,
      },
    ]
    @baseline = described_class.merge(root: @root, records: records)
  end

  after { FileUtils.remove_entry(@root) if @root }

  def commit_fixture
    system("git", "-C", @root, "add", ".", exception: true)
    system("git", "-C", @root, "commit", "--quiet", "-m", "Fixture", exception: true)
  end

  it "includes changes on main since an older mapping, including a new dependency" do
    File.write(File.join(@root, "lib/consumer.rb"), "consumer now calls shared")
    commit_fixture
    File.write(File.join(@root, "lib/shared.rb"), "PR changes shared")
    commit_fixture

    plan = described_class.plan(root: @root, baseline: @baseline)

    expect(plan["mode"]).to eq("subset")
    expect(plan["specs"]).to contain_exactly(
      "spec/models/shared_spec.rb",
      "spec/models/consumer_spec.rb",
    )
  end

  it "includes new specs and specs that previously failed" do
    File.write(File.join(@root, "spec/models/new_spec.rb"), "new spec")
    @baseline["specs"]["spec/models/consumer_spec.rb"]["passed"] = false
    commit_fixture
    plan = described_class.plan(root: @root, baseline: @baseline)
    expect(plan["specs"]).to contain_exactly(
      "spec/models/new_spec.rb",
      "spec/models/consumer_spec.rb",
    )
  end

  it "selects consumers of a removed source file" do
    File.delete(File.join(@root, "lib/shared.rb"))
    commit_fixture
    plan = described_class.plan(root: @root, baseline: @baseline)
    expect(plan["specs"]).to eq(["spec/models/shared_spec.rb"])
  end

  it "requires full execution when shared configuration changes" do
    File.write(File.join(@root, "config/settings.yml"), "changed: true")
    commit_fixture
    plan = described_class.plan(root: @root, baseline: @baseline)
    expect(plan["mode"]).to eq("full")
    expect(plan["reason"]).to eq("Shared or untraceable input changed")
  end

  it "requires full execution for added source files, including data files" do
    File.write(File.join(@root, "lib/new.json"), "{}")
    commit_fixture
    plan = described_class.plan(root: @root, baseline: @baseline)
    expect(plan["mode"]).to eq("full")
    expect(plan["reason"]).to eq("Shared or untraceable input changed")
  end

  it "requires full execution for unrecorded changes" do
    @baseline["specs"].delete("spec/models/shared_spec.rb")
    File.write(File.join(@root, "lib/shared.rb"), "changed")
    commit_fixture
    plan = described_class.plan(root: @root, baseline: @baseline)
    expect(plan["mode"]).to eq("full")
    expect(plan["reason"]).to eq("Unmapped source")
  end

  it "rejects missing or incompatible mappings and unavailable Git revisions" do
    expect(described_class.plan(root: @root, baseline: nil)["mode"]).to eq("full")
    expect(described_class.plan(root: @root, baseline: {})["mode"]).to eq("full")
    @baseline["revision"] = "f" * 40
    expect(described_class.plan(root: @root, baseline: @baseline)["mode"]).to eq("full")
  end

  it "rejects malformed dependency records" do
    @baseline["specs"] = nil
    expect(described_class.plan(root: @root, baseline: @baseline)["mode"]).to eq("full")
  end
end
